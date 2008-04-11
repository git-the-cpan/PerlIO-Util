/*
	PerlIO-Util/Util.xs

	PerlIO::flock - open with flock()
	PerlIO::creat - open with O_CREAT
	PerlIO::excl  - open with O_EXCL

*/
#define NDEBUG 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "perliol.h"

#include "perlioflock.h"

#ifdef NDEBUG
#define LayerFetch(layer, n) ((layer)->array[n].funcs)
#else
#define LayerFetch(layer, n) ( ((n) >= 0 && (n) < (layer)->cur) \
				? (layer)->array[n].funcs : (PerlIO_funcs*)0 )
#endif

static bool
is_perlio_layer(pTHX_ SV* sv)
{
	SV* o;
	if(!sv) return FALSE;

	SvGETMAGIC(sv);

	if(!SvROK(sv)) return FALSE;

	o = SvRV(sv);

	if(!SvOBJECT(o)) return FALSE;
	if(!SvIOK(o))    return FALSE;

	return sv_derived_from(sv, "PerlIO::Layer");
}


static IV
PerlIOFlock_pushed(pTHX_ PerlIO* fp, const char* mode, SV* arg,
		PerlIO_funcs* tab){

	IV lock_mode;

	if(!PerlIOValid(fp)){
		return -1;
	}

	lock_mode = (*fp)->flags & PERLIO_F_CANWRITE ? LOCK_EX : LOCK_SH;

	if(SvOK(arg)){
		const char* on_fail = SvPV_nolen(arg);

		if(strcmp(on_fail, "blocking") == 0){
			/* noop */
		}
		else if(strcmp(on_fail, "non-blocking") == 0){
			lock_mode |= LOCK_NB;
		}
		else{
			croak("PerlIO::flock: Unrecognized handler '%s' "
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

	croak("Useless use of ':%s' layer in binmode()", tab->name);
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
	if(!tab){
		tab = PerlIO_default_layer(aTHX_ 0);
	}

	assert(tab);
	assert(tab->Open);
/*
	warn("# open(tab=%s, mode=%s, imode=0x%x, perm=0%o)",
		tab->name, mode, imode, perm);
*/
	return (*tab->Open)(aTHX_ tab, layers, i+1,  mode,
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


MODULE = PerlIO::Util		PACKAGE = PerlIO::Layer

const char*
name(layer)
	PerlIO_funcs* layer
CODE:
	RETVAL = layer->name;
OUTPUT:
	RETVAL
