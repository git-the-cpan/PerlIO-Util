/*
	PerlIO-Util/Util.xs

	PerlIO::flock - open with flock()
	PerlIO::creat - open with O_CREAT
	PerlIO::excl  - open with O_EXCL

*/

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "perlioutil.h"
#include "perlioflock.h"

static IV
PerlIOFlock_pushed(pTHX_ PerlIO* fp, const char* mode, SV* arg,
		PerlIO_funcs* tab){

	IV lock_mode;

	assert(PerlIOValid(fp));

	lock_mode = (*fp)->flags & PERLIO_F_CANWRITE ? LOCK_EX : LOCK_SH;

	if(SvOK(arg)){
		const char* on_fail = SvPV_nolen(arg);

		if(strEQ(on_fail, "blocking")){
			/* noop */
		}
		else if(strEQ(on_fail, "non-blocking")
			|| strEQ(on_fail, "LOCK_NB")){
			lock_mode |= LOCK_NB;
		}
		else{
			Perl_croak(aTHX_ "Unrecognized :flock handler '%s' "
				"(it must be 'blocking' or 'non-blocking')",
				on_fail);
		}
	}

	PerlIO_flush(fp);
	return PerlLIO_flock(PerlIO_fileno(fp), lock_mode);
}

static IV
useless_pushed(pTHX_ PerlIO* fp, const char* mode, SV* arg,
		PerlIO_funcs* tab){

	if(ckWARN(WARN_LAYER)){
		Perl_warner(aTHX_ packWARN(WARN_LAYER),
			"Too late for :%s layer", tab->name);
	}
	SETERRNO(EINVAL, LIB_INVARG);
	return -1;
}

static PerlIO*
PerlIOUtil_open_with_flags(pTHX_ PerlIO_funcs* self, PerlIO_list_t* layers, IV n,
		const char* mode, int fd, int imode, int perm,
		PerlIO* f, int narg, SV** args, int flags){
	PerlIO_funcs* tab = NULL;
	char numeric_mode[5];
	int i;

	if(mode[0] != IoTYPE_NUMERIC){
		assert( sizeof(numeric_mode) > strlen(mode) );
		numeric_mode[0] = IoTYPE_NUMERIC;
		Copy(mode, &numeric_mode[1], strlen(mode), char*);
		mode = &numeric_mode[0];
	}

	if(imode){
		imode |= flags;
	}
	else{
		imode = PerlIOUnix_oflags(mode) | flags;
		perm = 0666;
	}


	for(i = n-1; i >= 0; i--){
		tab = LayerFetch(layers, i);

		if(tab && tab->Open){
			break;
		}
	}
	if(!(tab && tab->Open)){
		Perl_croak(aTHX_ "panic: lower layer not found");
	}
/*
	warn("# open(tab=%s, mode=%s, imode=0x%x, perm=0%o)",
		tab->name, mode, imode, perm);
//*/

	return (*tab->Open)(aTHX_ tab, layers, i,  mode,
				fd, imode, perm, f, narg, args);
}

static PerlIO*
PerlIOCreat_open(pTHX_ PerlIO_funcs* self, PerlIO_list_t* layers, IV n,
		  const char* mode, int fd, int imode, int perm,
		  PerlIO* f, int narg, SV** args){

	return PerlIOUtil_open_with_flags(aTHX_ self, layers, n, mode, fd, imode,
			perm, f, narg, args, O_CREAT);
}

static PerlIO*
PerlIOExcl_open(pTHX_ PerlIO_funcs* self, PerlIO_list_t* layers, IV n,
		  const char* mode, int fd, int imode, int perm,
		  PerlIO* f, int narg, SV** args){

	return PerlIOUtil_open_with_flags(aTHX_ self, layers, n, mode, fd, imode,
			perm, f, narg, args, O_EXCL);
}


/* :flock */
PERLIO_FUNCS_DECL(PerlIO_flock) = {
	sizeof(PerlIO_funcs),
	"flock", /* name */
	0, /* size */
	PERLIO_K_DUMMY, /* kind */
	PerlIOFlock_pushed, /* pushed */
	NULL, /* popped */
	NULL, /* open */
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

/* :creat */
PERLIO_FUNCS_DECL(PerlIO_creat) = {
	sizeof(PerlIO_funcs),
	"creat", /* name */
	0, /* size */
	PERLIO_K_DUMMY, /* kind */
	useless_pushed, /* pushed */
	NULL, /* popped */
	PerlIOCreat_open, /* open */
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

/* :excl */
PERLIO_FUNCS_DECL(PerlIO_excl) = {
	sizeof(PerlIO_funcs),
	"excl", /* name */
	0, /* size */
	PERLIO_K_DUMMY, /* kind */
	useless_pushed, /* pushed */
	NULL, /* popped */
	PerlIOExcl_open, /* open */
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


MODULE = PerlIO::Util		PACKAGE = PerlIO::Util		

PROTOTYPES: DISABLE

BOOT:
	PerlIO_define_layer(aTHX_ PERLIO_FUNCS_CAST(&PerlIO_flock));
	PerlIO_define_layer(aTHX_ PERLIO_FUNCS_CAST(&PerlIO_creat));
	PerlIO_define_layer(aTHX_ PERLIO_FUNCS_CAST(&PerlIO_excl));

void
known_layers(...)
PREINIT:
	PerlIO_list_t* layers = PL_known_layers;
	int i;
PPCODE:
	EXTEND(SP, layers->cur);
	for(i = 0; i < layers->cur; i++){
		SV* name = newSVpv( LayerFetch(layers, i)->name, 0);
		PUSHs( sv_2mortal(name) );
	}
	XSRETURN(layers->cur);

MODULE = PerlIO::Util		PACKAGE = IO::Handle

#define undef Nullsv

void
push_layer(filehandle, layer, arg = undef)
	PerlIO* filehandle
	SV* layer
	SV* arg
PREINIT:
	PerlIO_funcs* tab;
	const char* laypv;
	STRLEN laylen;
PPCODE:
	laypv = SvPV(layer, laylen);
	if(laypv[0] == ':'){ /* ignore this layer prefix */
		laypv++;
		laylen--;
	}
	tab = PerlIO_find_layer(aTHX_ laypv, laylen, TRUE);
	if(tab){
		if(!PerlIO_push(aTHX_ filehandle, tab, Nullch, arg)){
			Perl_croak(aTHX_ "push_layer() failed: %s",
				PerlIOValid(filehandle)
					? Strerror(errno)
					: "Invalid filehandle");
		}
	}
	else{
		Perl_croak(aTHX_ "Unknown PerlIO layer \"%.*s\"",
				(int)laylen, laypv);
	}
	XSRETURN(1);

void
pop_layer(filehandle)
	PerlIO* filehandle
PREINIT:
	const char* poped_layer = Nullch;
PPCODE:
	if(PerlIOValid(filehandle)){
		poped_layer = (*filehandle)->tab->name;

		PerlIO_flush(filehandle);
		PerlIO_pop(aTHX_ filehandle);
	}
	else{
		Perl_croak(aTHX_ "Invalid filehandle");
	}
	if(GIMME_V != G_VOID){
		XSRETURN_PV(poped_layer);
	}

