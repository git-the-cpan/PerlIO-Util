/*
	:tee - write to files.

	Usage: open(my $out, '>>:tee', \*STDOUT, \*SOCKET, $file, \$scalar)
	       $out->push_layer(tee => $another);
*/

#include "perlioutil.h"

#define CanWrite(fp) (PerlIOBase(fp)->flags & PERLIO_F_CANWRITE)

#define TeeOut(f) (PerlIOSelf(f, PerlIOTee)->out)
#define TeeArg(f) (PerlIOSelf(f, PerlIOTee)->arg)

/* copied from perlio.c */
static PerlIO_funcs *
PerlIO_layer_from_ref(pTHX_ SV *sv)
{
    dVAR;
    /*
     * For any scalar type load the handler which is bundled with perl
     */
    if (SvTYPE(sv) < SVt_PVAV) {
	PerlIO_funcs *f = PerlIO_find_layer(aTHX_ STR_WITH_LEN("scalar"), 1);
	/* This isn't supposed to happen, since PerlIO::scalar is core,
	 * but could happen anyway in smaller installs or with PAR */
	if (!f && ckWARN(WARN_LAYER))
	    Perl_warner(aTHX_ packWARN(WARN_LAYER), "Unknown PerlIO layer \"scalar\"");
	return f;
    }

    /*
     * For other types allow if layer is known but don't try and load it
     */
    switch (SvTYPE(sv)) {
    case SVt_PVAV:
	return PerlIO_find_layer(aTHX_ STR_WITH_LEN("Array"), 0);
    case SVt_PVHV:
	return PerlIO_find_layer(aTHX_ STR_WITH_LEN("Hash"), 0);
    case SVt_PVCV:
	return PerlIO_find_layer(aTHX_ STR_WITH_LEN("Code"), 0);
    case SVt_PVGV:
	return PerlIO_find_layer(aTHX_ STR_WITH_LEN("Glob"), 0);
    default:
	return NULL;
    }
} /* PerlIO_layer_from_ref() */



typedef struct {
	struct _PerlIO base; /* virtual table and flags */

	SV* arg;

	PerlIO* out;
} PerlIOTee;


static PerlIO*
PerlIOTee_open(pTHX_ PerlIO_funcs* self, PerlIO_list_t* layers, IV n,
		  const char* mode, int fd, int imode, int perm,
		  PerlIO* f, int narg, SV** args){
	SV* arg;

	if(!(PerlIOUnix_oflags(mode) & O_WRONLY)){ /* cannot open:tee for reading */
		SETERRNO(EINVAL, LIB_INVARG);
		return NULL;
	}

	f = PerlIOUtil_openn(aTHX_ NULL, layers, n, mode,
				fd, imode, perm, f, 1, args);

	if(!f){
		return NULL;
	}

	if(narg > 1){
		int i;
		for(i = 1; i < narg; i++){
			if(!PerlIO_push(aTHX_ f, self, mode, args[i])){
				PerlIO_close(f);
				return NULL;
			}
		}
	}

	arg = PerlIOArg;
	if(arg && SvOK(arg)){
		if(!PerlIO_push(aTHX_ f, self, mode, arg)){
			PerlIO_close(f);
			return NULL;
		}
	}

	return f;
}


static SV*
parse_fname(pTHX_ SV* arg, const char** mode){
	STRLEN len;
	const char* pv = SvPV(arg, len);

	switch (*pv){
	case '>':
		pv++;
		len--;
		if(*pv == '>'){ /* ">> file" */
			pv++;
			len--;
			*mode = "a";
		}
		else{ /* "> file" */
			*mode = "w";
		}
		while(isSPACE(*pv)){
			pv++;
			len--;
		}
		break;

	case '+':
	case '<':
	case '|':
		Perl_croak(aTHX_ "Unacceptable open mode '%c' (it must be '>' or '>>')",
			*pv);
	default:
		/* noop */;
	}
	return newSVpvn(pv, len);
}

static IV
PerlIOTee_pushed(pTHX_ PerlIO* f, const char* mode, SV* arg, PerlIO_funcs* tab){
	PerlIO* next = PerlIONext(f);
	IO* io;

	PERL_UNUSED_ARG(tab);

	if(!CanWrite(next)) goto cannot_tee;

	if(SvROK(arg) && (io = GvIO(SvRV(arg)))){
		if(!( IoOFP(io) && CanWrite(IoOFP(io)) )){
			cannot_tee:
			SETERRNO(EBADF, SS_IVCHAN);
			return -1;
		}

		TeeArg(f) = SvREFCNT_inc_simple_NN( (SV*)io );
		TeeOut(f) = IoOFP(io);
	}
	else{
		PerlIO_list_t*  layers = PL_def_layerlist;
		PerlIO_funcs* tab = NULL;

		if(SvPOK(arg) && SvCUR(arg) > 1){
			TeeArg(f) = parse_fname(aTHX_ arg, &mode);
		}
		else{
			TeeArg(f) = newSVsv(arg);

		}

		if( SvROK(TeeArg(f)) ){
			tab = PerlIO_layer_from_ref(aTHX_ SvRV(TeeArg(f)));
		}

		if(!mode){
			mode = "w";
		}

		TeeOut(f) = PerlIOUtil_openn(aTHX_ tab, layers,
			layers->cur, mode, -1, 0, 0, NULL, 1, &(TeeArg(f)));

		/*dump_perlio(aTHX_ TeeOut(f), 0);*/
	}
	if(!PerlIOValid(TeeOut(f))){
		return -1; /* failure */
	}

	PerlIOBase(f)->flags = PerlIOBase(next)->flags;

	IOLflag_on(TeeOut(f),
		PerlIOBase(f)->flags & (PERLIO_F_UTF8 | PERLIO_F_LINEBUF | PERLIO_F_UNBUF));

	return 0;
}

static IV
PerlIOTee_popped(pTHX_ PerlIO* f){
	if(TeeArg(f) && SvTYPE(TeeArg(f)) != SVt_PVIO){
		PerlIO_close(TeeOut(f));
	}
	SvREFCNT_dec(TeeArg(f));
	return 0;
}

static IV
PerlIOTee_binmode(pTHX_ PerlIO* f){
	if(!PerlIOValid(f)){
		return -1;
	}

	PerlIOBase_binmode(aTHX_ f); /* remove PERLIO_F_UTF8 */

	PerlIO_binmode(aTHX_ PerlIONext(f), '>', O_BINARY, Nullch);

	/* warn("Tee_binmode %s", PerlIOBase(f)->tab->name); */
	/* there is a case where an unknown layer is supplied */
	if( PerlIOBase(f)->tab != &PerlIO_tee ){
#if 0 /* May, 2008 */
		PerlIO* t = PerlIONext(f);
		int n = 0;
		int ok = 0;

		while(PerlIOValid(t)){
			if(PerlIOBase(t)->tab == &PerlIO_tee){
				n++;
				if(PerlIO_binmode(aTHX_ TeeOut(t), '>'/*not used*/,
					O_BINARY, Nullch)){
					ok++;
				}
			}

			t = PerlIONext(t);
		}
		return n == ok ? 0 : -1;
#endif
		return 0;
	}

	return PerlIO_binmode(aTHX_ TeeOut(f), '>'/*not used*/,
				O_BINARY, Nullch) ? 0 : -1;
}

static SV*
PerlIOTee_getarg(pTHX_ PerlIO* f, CLONE_PARAMS* param, int flags){
	PERL_UNUSED_ARG(flags);

	return PerlIO_sv_dup(aTHX_ TeeArg(f), param);
}

static SSize_t
PerlIOTee_write(pTHX_ PerlIO* f, const void* vbuf, Size_t count){
	if(PerlIO_write(TeeOut(f), vbuf, count) != (SSize_t)count){
		Perl_warner(aTHX_ packWARN(WARN_IO), "Failed to write to tee-out");
	}

	return PerlIO_write(PerlIONext(f), vbuf, count);
}

static IV
PerlIOTee_flush(pTHX_ PerlIO* f){
	if(PerlIO_flush(TeeOut(f)) != 0){
		Perl_warner(aTHX_ packWARN(WARN_IO), "Failed to flush tee-out");
	}

	return PerlIO_flush(PerlIONext(f));
}

static IV
PerlIOTee_seek(pTHX_ PerlIO* f, Off_t offset, int whence){
	if(PerlIO_seek(TeeOut(f), offset, whence) != 0){
		Perl_warner(aTHX_ packWARN(WARN_IO), "Failed to seek tee-out");
	}

	return PerlIO_seek(PerlIONext(f), offset, whence);
}

static Off_t
PerlIOTee_tell(pTHX_ PerlIO* f){
	PerlIO* next = PerlIONext(f);

	return PerlIO_tell(next);
}

PerlIO*
PerlIOTee_teeout(pTHX_ const PerlIO* f){
	return PerlIOValid(f) ? TeeOut(f) : NULL;
}


PERLIO_FUNCS_DECL(PerlIO_tee) = {
    sizeof(PerlIO_funcs),
    "tee",
    sizeof(PerlIOTee),
    PERLIO_K_BUFFERED | PERLIO_K_RAW | PERLIO_K_MULTIARG,
    PerlIOTee_pushed,
    PerlIOTee_popped,
    PerlIOTee_open,
    PerlIOTee_binmode,
    PerlIOTee_getarg,
    NULL, /* fileno */
    NULL, /* dup */
    NULL, /* read */
    NULL, /* unread */
    PerlIOTee_write,
    PerlIOTee_seek,
    PerlIOTee_tell,
    NULL, /* close */
    PerlIOTee_flush,
    NULL, /* fill */
    NULL, /* eof */
    NULL, /* error */
    NULL, /* clearerror */
    NULL, /* setlinebuf */
    NULL, /* get_base */
    NULL, /* bufsiz */
    NULL, /* get_ptr */
    NULL, /* get_cnt */
    NULL, /* set_ptrcnt */
};


