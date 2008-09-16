/*
	PerlIO::fse - File System Encoding

*/

#include "perlioutil.h"

#define DEFAULT_FSE "UTF-8"

#ifdef __CYGWIN__
#include <windows.h>
#endif

SV*
PerlIOFSE_get_fse(pTHX){
	SV* fse = get_sv("PerlIO::Util::fse", GV_ADDMULTI);

	if (!SvOK(fse)) {
#if defined(WIN32) || defined(__CYGWIN__)
		unsigned long codepage = GetACP();
		if(codepage != 0){
			Perl_sv_setpvf(aTHX_ fse, "cp%lu", codepage);
		}
#endif

		if(!PL_tainting){
			const char* env_fse = PerlEnv_getenv("PERLIO_FSE");
			if(env_fse && *env_fse){
				sv_setpv(fse, env_fse);
			}
		}

		if(!SvOK(fse)){
			sv_setpvs(fse, DEFAULT_FSE);
		}
		PerlIO_debug("PerlIOFSE_initialize: encoding=%" SVf , fse);
	}

	return fse;
}

static SV*
PerlIOFSE_encode(pTHX_ SV* enc, SV* data){
	dSP;
	SV* bytes;

	PerlIO_debug("PerlIOFSE_encode(%" SVf ", %" SVf ")",
		enc, data);


	/* load Encode.pm */
	if(!get_sv("Encode::VERSION", FALSE)){
		/* Actually, I don't know why PUSHSTACK/POPSTACK should be called. */
		PUSHSTACK;
		Perl_load_module(aTHX_ PERL_LOADMOD_NOIMPORT,
			newSVpvs("Encode"), Nullsv, Nullsv);
		POPSTACK;
	}

	PUSHMARK(sp);
	EXTEND(sp, 2);
	PUSHs(enc);
	PUSHs(data);
	PUTBACK;

	call_pv("Encode::encode", G_SCALAR);

	SPAGAIN;
	bytes = POPs;
	PUTBACK;

	return bytes;
}

static PerlIO*
PerlIOFSE_open(pTHX_ PerlIO_funcs* self, PerlIO_list_t* layers, IV n,
		const char* mode, int fd, int imode, int perm,
		PerlIO* f, int narg, SV** args){

	PERL_UNUSED_ARG(self);


	if(SvUTF8(args[0])){
		SV* fse;
		SV* arg = PerlIOArg;
		SV* save;

		if(arg && SvOK(arg)){
			fse = arg;
		}
		else{
			fse = PerlIOFSE_get_fse(aTHX);
		}

		if(!SvOK(fse)){
			Perl_croak(aTHX_ "fse: encoding not set");
		}

		ENTER;
		SAVETMPS;

		save = args[0];
		args[0] = PerlIOFSE_encode(aTHX_ fse, args[0]);
	
		f = PerlIOUtil_openn(aTHX_ NULL, layers, n,
				mode, fd, imode, perm, f, narg, args);

		args[0] = save;

		FREETMPS;
		LEAVE;

		return f;
	}

	return PerlIOUtil_openn(aTHX_ NULL, layers, n,
			mode, fd, imode, perm, f, narg, args);

}

PERLIO_FUNCS_DECL(PerlIO_fse) = {
	sizeof(PerlIO_funcs),
	"fse",
	0, /* size */
	PERLIO_K_DUMMY, /* kind */
	PerlIOUtil_useless_pushed,
	NULL, /* popped */
	PerlIOFSE_open,
	NULL, /* binmode */
	NULL, /* arg */
	NULL, /* fileno */
	NULL, /* dup */
	NULL, /* read */
	NULL, /* unread */
	NULL, /* write */
	NULL, /* seek */
	NULL, /* tell */
	NULL, /* close */
	NULL, /* flush */
	NULL, /* fill */
	NULL, /* eof */
	NULL, /* error */
	NULL, /* clearerr */
	NULL, /* setlinebuf */
	NULL, /* get_base */
	NULL, /* bufsiz */
	NULL, /* get_ptr */
	NULL, /* get_cnt */
	NULL  /* set_ptrcnt */
};
