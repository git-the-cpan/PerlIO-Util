/*
   :reverse - Reads lines backward
 */
#include "perlioutil.h"

#define IOR(f) (PerlIOSelf(f, PerlIOReverse))

#undef BUFSIZ

#define BUFSIZ 2048
#define SEGSV_BUFSIZ 512
#define BUFSV_BUFSIZ (BUFSIZ+SEGSV_BUFSIZ)

enum iorev_state{
	first_reading,
	end_newline,
	not_end_newline,
};

typedef struct{
	struct _PerlIO base;

	SV* segsv; /* broken segment */

	SV* bufsv; /* reversed buffer */
	STDCHAR* ptr;
	STDCHAR* end;

	enum iorev_state state;
} PerlIOReverse;


static IV
PerlIOReverse_pushed(pTHX_ PerlIO *f, const char *mode, SV *arg, PerlIO_funcs *tab){
	PerlIOReverse* ior;
	PerlIO* nx  = PerlIONext(f);

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

	if(!PerlIO_binmode(aTHX_ nx, '<', O_BINARY, Nullch)){
		SETERRNO(EINVAL, LIB_INVARG);
		return -1;
	}

	if(PerlIO_tell(nx) == 0){
		if(PerlIO_seek(nx, (Off_t)0, SEEK_END) < 0){
			return -1;
		}
	}
	ior = IOR(f);
	ior->segsv = newSV(SEGSV_BUFSIZ);
	ior->bufsv = newSV(BUFSV_BUFSIZ);
	ior->state = first_reading;

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
			" size of bufsv=%ld, size of segsv=%ld\n",
			(long)SvLEN(ior->bufsv), (long)SvLEN(ior->segsv));

	SvREFCNT_dec(ior->bufsv);
	SvREFCNT_dec(ior->segsv);

	return PerlIOBase_popped(aTHX_ f);
}

#define write_buf(s, l, m)   PerlIOReverse_debug_write_buf(s, l, m)
#define write_bufsv(sv, msg) PerlIOReverse_debug_write_buf(SvPVX(sv), SvCUR(sv), msg)

/* to pass -Wmissing-prototypes -Wunused-function */
void PerlIOReverse_debug_write_buf(register const STDCHAR*, const Size_t count, const STDCHAR* msg);

void
PerlIOReverse_debug_write_buf(register const STDCHAR* src, const Size_t count, const STDCHAR* msg){
	dTHX;
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
	warn("]");
	//PerlIO_write(PerlIO_stderr(), "]\n", 2);

	Safefree(buf);
}


static SSize_t
reverse_read(pTHX_ PerlIO* f, STDCHAR* vbuf, SSize_t count){
	PerlIOReverse* ior = IOR(f);
	PerlIO* nx = PerlIONext(f);
	Off_t pos;

	if(ior->state == first_reading) count--; /* for extra newline */

	pos = PerlIO_tell(nx);
	if(pos <= 0){
		IOLflag_on(f, pos < 0 ? PERLIO_F_ERROR : PERLIO_F_EOF);
		return -1;
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
	if(PerlIO_seek(nx, (Off_t)-count, SEEK_CUR) < 0){
		return -1;
	}

	if(ior->state == first_reading){
		if(vbuf[count-1] == '\n'){
			ior->state = end_newline;
		}
		else{
			ior->state = not_end_newline;
			vbuf[count] = '\n';
			count++;
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

	STDCHAR buf[BUFSIZ];
	STDCHAR* ptr;
	STDCHAR* end;
	STDCHAR* start;

	IOLflag_off(f, PERLIO_F_RDBUF);

	SvCUR_set(bufsv, 0);

	retry:
	avail = reverse_read(aTHX_ f, buf, BUFSIZ);

	if(avail < 0){
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
			STRLEN line_len = ptr - start;

			Copy( start,
			      rbuf + (end - ptr),
			      line_len, STDCHAR);

			start = ptr;
		}
	}

	if(IOLflag(f, PERLIO_F_EOF) && ior->state == not_end_newline){
		SvCUR(bufsv)--; /* chop */
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
	NULL, /* open */
	NULL, /* binmode */
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
