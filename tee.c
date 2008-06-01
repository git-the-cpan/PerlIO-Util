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
	PerlIO_funcs* tab;
	SV* arg;
	const char* p;

	p = mode;
	while(*p){
		if(*p == 'r' || *p == '+'){
			Perl_croak(aTHX_ "Cannot open:tee for reading");
		}
		p++;
	}

	tab = LayerFetchSafe(layers, n - 1);

	if(!(tab && tab->Open)){
		SETERRNO(EINVAL, LIB_INVARG);
		return NULL;
	}

	f  = tab->Open(aTHX_ tab, layers, n - 1,  mode,
				fd, imode, perm, f, 1, args); /* delegation */
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

		if(!tab){
			tab = LayerFetch(layers, layers->cur-1);
		}

		if(!mode){
			mode = "w";
		}

		assert(tab);

		PerlIO_debug("PerlIOTee_pushed %s(%s)\n",
			tab->name, SvPV_nolen(TeeArg(f)));

		TeeOut(f) = tab->Open(aTHX_ tab, layers,
			layers->cur-1, mode, -1, 0, 0, NULL, 1, &(TeeArg(f)));

		/*dump_perlio(aTHX_ TeeOut(f), 0);*/
	}
	if(!PerlIOValid(TeeOut(f))){
		return -1; /* failure */
	}

	PerlIOBase(f)->flags = PerlIOBase(next)->flags;

	IOLflag_on(TeeOut(f), PerlIOBase(f)->flags & PERLIO_F_UTF8);

	return 0;
}

static IV
PerlIOTee_popped(pTHX_ PerlIO* f){
	if(TeeArg(f) && SvTYPE(TeeArg(f)) != SVt_PVIO){
		PerlIO_close(TeeOut(f));
	}
	TeeOut(f) = NULL;

	SvREFCNT_dec(TeeArg(f));
	TeeArg(f) = NULL;
	return 0;
}

#ifdef PERLIOUTIL_WIN32_EMULATE /*  2008/05/22 */
#define PERLIO_USING_CRLF

static IV
win32_crlf_binmode(pTHX_ PerlIO *f)
{
    if ((PerlIOBase(f)->flags & PERLIO_F_CRLF)) {
	/* In text mode - flush any pending stuff and flip it */
	PerlIOBase(f)->flags &= ~PERLIO_F_CRLF;
#ifndef PERLIO_USING_CRLF
	/* CRLF is unusual case - if this is just the :crlf layer pop it */
	if (PerlIOBase(f)->tab == &PerlIO_crlf) {
		PerlIO_pop(aTHX_ f);
	}
#endif
    }
    return 0;
}
#undef PERLIO_USING_CRLF
#endif

static IV
PerlIOTee_binmode(pTHX_ PerlIO* f){
	if(!PerlIOValid(f)){
		return -1;
	}

#ifdef PERLIOUTIL_WIN32_EMULATE
	((PerlIO_funcs*)&PerlIO_crlf)->Binmode = &win32_crlf_binmode;
#endif
	PerlIOBase_binmode(aTHX_ f); /* remove PERLIO_F_UTF8 */

	PerlIO_binmode(aTHX_ PerlIONext(f), '>', O_BINARY, Nullch);

	/* warn("Tee_binmode %s", PerlIOBase(f)->tab->name); */
	/* there is a case where an unknown layer is supplied */
	if( PerlIOBase(f)->tab != &PerlIO_tee ){
#if 0
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
	PerlIO* next = PerlIONext(f);

	if(PerlIO_write(TeeOut(f), vbuf, count) != (SSize_t)count){
		Perl_warner(aTHX_ packWARN(WARN_IO), "Failed to write to tee");
	}

	return PerlIO_write(next, vbuf, count);
}

static IV
PerlIOTee_flush(pTHX_ PerlIO* f){
	PerlIO* next = PerlIONext(f);

	if(PerlIO_flush(TeeOut(f)) != 0){
		Perl_warner(aTHX_ packWARN(WARN_IO), "Failed to flush to tee");
	}

	return PerlIO_flush(next);
}

static IV
PerlIOTee_seek(pTHX_ PerlIO* f, Off_t offset, int whence){
	PerlIO* next = PerlIONext(f);
	IV code;

	if((code = PerlIOTee_flush(aTHX_ f)) == 0){
		if(PerlIO_seek(TeeOut(f), offset, whence) != 0){
			Perl_warner(aTHX_ packWARN(WARN_IO), "Failed to seek to tee");
		}

		code = PerlIO_seek(next, offset, whence);
	}

	return code;
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


