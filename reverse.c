/*
   :reverse - Reads lines backward
 */
#include "perlioutil.h"

#define IOR(f) (PerlIOSelf(f, PerlIOReverse))


#define REV_BUFSIZ 4096

#define SEGSV_BUFSIZ 512
#define BUFSV_BUFSIZ (REV_BUFSIZ+SEGSV_BUFSIZ)


typedef struct{
	struct _PerlIO base;

	SV* segsv; /* broken segment */

	SV* bufsv; /* reversed buffer */
	STDCHAR* ptr;
	STDCHAR* end;
} PerlIOReverse;

static PerlIO*
PerlIOReverse_open(pTHX_ PerlIO_funcs* self, PerlIO_list_t* layers, IV n,
		  const char* mode, int fd, int imode, int perm,
		  PerlIO* f, int narg, SV** args){
	PerlIO_funcs* tab;

	tab = LayerFetchSafe(layers, 0); /* :unix or :stdio */

	if(!(tab && tab->Open)){
		SETERRNO(EINVAL, LIB_INVARG);
		return NULL;
	}

	if( PerlIOUnix_oflags(mode) & (O_WRONLY | O_RDWR) ){
		SETERRNO(EINVAL, LIB_INVARG);
		return NULL;
	}

	f = tab->Open(aTHX_ tab, layers, (IV)1, mode, fd, imode, perm, f, narg, args);

/*
	if(LayerFetchSafe(layers, layers->cur-2)->kind & PERLIO_K_CANCRLF){
		// to do something?
	}
*/
	if(f){
		if(!PerlIO_push(aTHX_ f, self, mode, PerlIOArg)){
			PerlIO_close(f);
			return NULL;
		}
	}
	return f;
}

static IV
PerlIOReverse_pushed(pTHX_ PerlIO *f, const char *mode, SV *arg, PerlIO_funcs *tab){
	PerlIOReverse* ior;
	PerlIO* nx  = PerlIONext(f);
	Off_t pos;
	PerlIO* p;

	if(!PerlIOValid(nx)){
		SETERRNO(EBADF, SS_IVCHAN);
		return -1;
	}

	if(IOLflag(nx, PERLIO_F_TTY)){
		SETERRNO(EINVAL, LIB_INVARG);
		return -1;
	}

	if(!IOLflag(nx, PERLIO_F_CANREAD)){
		SETERRNO(EINVAL, LIB_INVARG);
		return -1;
	}

	for(p = nx; PerlIOValid(p); p = PerlIONext(p)){
		if(!(PerlIOBase(p)->tab->kind & PERLIO_K_RAW)
			|| (PerlIOBase(p)->flags & PERLIO_F_CRLF)){

			Perl_warner(aTHX_ packWARN(WARN_LAYER),
				":%s is not a raw layer",
				PerlIOBase(p)->tab->name);
			SETERRNO(EINVAL, LIB_INVARG);
			return -1;
		}
	}
/*
	if(!PerlIO_binmode(aTHX_ nx, '<', O_BINARY, Nullch)){
		SETERRNO(EINVAL, LIB_INVARG);
		return -1;
	}
*/
	pos = PerlIO_tell(nx);
	if(pos <= 0){
		if(pos < 0 || PerlIO_seek(nx, (Off_t)0, SEEK_END) < 0){
			return -1;
		}
	}
	ior = IOR(f);
	ior->segsv = newSV(SEGSV_BUFSIZ);
	ior->bufsv = newSV(BUFSV_BUFSIZ);

	assert( ior->bufsv );
	assert( ior->segsv );

	sv_setpvn(ior->bufsv, "", 0);
	sv_setpvn(ior->segsv, "", 0);

	return PerlIOBase_pushed(aTHX_ f, mode, arg, tab);
}
static IV
PerlIOReverse_popped(pTHX_ PerlIO* f){
	PerlIOReverse* ior = IOR(f);

	PerlIO_debug("PerlIOReverse_popped:"
			" bufsv=%ld, segsv=%ld\n",
			(long)(ior->bufsv ? SvLEN(ior->bufsv) : 0),
			(long)(ior->segsv ? SvLEN(ior->segsv) : 0));

	SvREFCNT_dec(ior->bufsv);
	SvREFCNT_dec(ior->segsv);

	return PerlIOBase_popped(aTHX_ f);
}

#define write_buf(s, l, m)   PerlIOReverse_debug_write_buf(aTHX_ s, l, m)
#define write_bufsv(sv, msg) PerlIOReverse_debug_write_buf(aTHX_ SvPVX(sv), SvCUR(sv), msg)

/* to pass -Wmissing-prototypes -Wunused-function */
void
PerlIOReverse_debug_write_buf(pTHX_ register const STDCHAR*, const Size_t count, const STDCHAR* msg);

void
PerlIOReverse_debug_write_buf(pTHX_ register const STDCHAR* src, const Size_t count, const STDCHAR* msg){
	char* buf;
	char* end;
	register char* ptr;

	Newx(buf, count, char);

	ptr = buf;
	end = buf + count;
	/* write the buffer */

	while(ptr < end){
		*ptr = (*src == '\0' ? '@' : *src);
		ptr++;
		src++;
	}
	if(msg){
		PerlIO_write(PerlIO_stderr(), msg, strlen(msg));
	}
	PerlIO_write(PerlIO_stderr(), "[", 1);
	PerlIO_write(PerlIO_stderr(), buf, count);
	Perl_warn(aTHX_ "]");
	//PerlIO_write(PerlIO_stderr(), "]\n", 2);

	Safefree(buf);
}


static SSize_t
reverse_read(pTHX_ PerlIO* f, STDCHAR* vbuf, SSize_t count){
	PerlIO* nx = PerlIONext(f);
	Off_t pos;

	pos = PerlIO_tell(nx);
	if(pos <= 0){
		IOLflag_on(f, pos < 0 ? PERLIO_F_ERROR : PERLIO_F_EOF);
		return 0;
	}

	if(pos <= count){
		if(PerlIO_seek(nx, (Off_t)0, SEEK_SET) < 0){
			IOLflag_on(f, PERLIO_F_ERROR);
			return -1;
		}
		IOLflag_on(f, PERLIO_F_EOF);

		count = (SSize_t)pos;
	}
	else{
		if(PerlIO_seek(nx, (Off_t)-count, SEEK_CUR) < 0){
			IOLflag_on(f, PERLIO_F_ERROR);
			return -1;
		}
	}

	count = PerlIO_read(nx, vbuf, (Size_t)count);

	if(count > 0){
		if(PerlIO_seek(nx, (Off_t)-count, SEEK_CUR) < 0){
			return -1;
		}
	}

	return count;
}


static IV
PerlIOReverse_fill(pTHX_ PerlIO* f){
	PerlIOReverse* ior = IOR(f);
	SSize_t avail;

	SV* bufsv = ior->bufsv;
	SV* segsv = ior->segsv;
	STDCHAR* rbuf;

	STDCHAR  buf[ REV_BUFSIZ ];
	STDCHAR* ptr;
	STDCHAR* end;
	STDCHAR* start;

	IOLflag_off(f, PERLIO_F_RDBUF);

	SvCUR(bufsv) = 0;

	retry:
	avail = reverse_read(aTHX_ f, buf, REV_BUFSIZ);

	if(avail <= 0){
		IOLflag_on(f, avail < 0 ? PERLIO_F_ERROR : PERLIO_F_EOF);
		return -1;
	}

	start = ptr = buf;
	end = buf + avail;

	if(!IOLflag(f, PERLIO_F_EOF)){
		while(ptr < end){
			if(*(ptr++) == '\n') break;
		}

		if(ptr >= end){ /* only one line or segment not ending newline */

			/* fill segment simply */
			sv_insert(segsv, 0, 0, buf, (Size_t)(ptr - start));
			goto retry;
		}
	}


	/* solve old segment */
	if(SvCUR(segsv) > 0){
		/* buf[oo\nbar\nba]
		       ^   ^    ^
		                p
		   seg[z\n]
		*/
		STDCHAR* p = end;
		while(p >= ptr){
			if(*(--p) == '\n') break;
		}
		p++;

		sv_grow(bufsv, (end - ptr) + SvCUR(segsv));

		sv_setpvn(bufsv, p, (Size_t)(end - p));
		sv_catsv( bufsv, segsv);
		end = p;
	}

	sv_setpvn(segsv, start, (Size_t)(ptr - start));
	start = ptr;

	rbuf = SvPVX(bufsv) + SvCUR(bufsv);
	SvCUR(bufsv) += end - start;

	assert(SvCUR(bufsv) <= SvLEN(bufsv));

	while(ptr < end){
		if(*(ptr++) == '\n'){
			/* line length: ptr - start */
			/* write pos:   end - ptr   */

			Copy( start,
			      rbuf + (end - ptr),
			      ptr - start, STDCHAR);

			start = ptr;
		}
	}
	if(start != end){
		Copy( start, rbuf + (end - ptr), ptr - start, STDCHAR);
	}


/*
	write_bufsv(segsv, "segm");
	write_buf(start, end - start, "buf");
	write_bufsv(segsv, "rbuf");
// */
	ior->ptr = SvPVX(bufsv);
	ior->end = SvPVX(bufsv) + SvCUR(bufsv);

	IOLflag_on(f, PERLIO_F_RDBUF);

	return 0;
}

static STDCHAR*
PerlIOReverse_get_base(pTHX_ PerlIO* f){
	return SvPVX(IOR(f)->bufsv);
}

static STDCHAR*
PerlIOReverse_get_ptr(pTHX_ PerlIO* f){
	return IOR(f)->ptr;
}

static SSize_t
PerlIOReverse_get_cnt(pTHX_ PerlIO* f){
	return IOR(f)->end - IOR(f)->ptr;
}

static Size_t
PerlIOReverse_bufsiz(pTHX_ PerlIO* f){
	return SvCUR(IOR(f)->bufsv);
}

static void
PerlIOReverse_set_ptrcnt(pTHX_ PerlIO* f, STDCHAR* ptr, SSize_t cnt){
	PERL_UNUSED_ARG(cnt);

	IOR(f)->ptr  = ptr;

	assert( PerlIO_get_cnt(f) == cnt );
}

PERLIO_FUNCS_DECL(PerlIO_reverse) = {
	sizeof(PerlIO_funcs),
	"reverse",
	sizeof(PerlIOReverse),
	PERLIO_K_BUFFERED | PERLIO_K_RAW,
	PerlIOReverse_pushed,
	PerlIOReverse_popped,
	PerlIOReverse_open,
	PerlIOBase_binmode,
	NULL, /* getarg */
	NULL, /* fileno */
	NULL, /* dup */
	NULL, /* read */
	NULL, /* unread */
	NULL, /* write */
	NULL, /* seek */
	NULL, /* tell */
	NULL, /* close */
	NULL, /* flush */
	PerlIOReverse_fill,
	NULL, /* eof */
	NULL, /* error */
	NULL, /* clearerr */
	NULL, /* setlinebuf */
	PerlIOReverse_get_base,
	PerlIOReverse_bufsiz,
	PerlIOReverse_get_ptr,
	PerlIOReverse_get_cnt,
	PerlIOReverse_set_ptrcnt
};
