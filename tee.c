/*
	:tee - write to files.

	Usage: open(my $out, '>>:tee', \*STDOUT, \*SOCKET, $file, \$scalar)
	       $out->push_layer(tee => $another);
*/

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "perlioutil.h"

#define CanWrite(fp) (PerlIOBase(fp)->flags & PERLIO_F_CANWRITE)


typedef struct {
	struct _PerlIO base; /* virtual table and flags */

	SV* arg;

	PerlIO* out;
} PerlIOTee;


static PerlIO*
PerlIOTee_open(pTHX_ PerlIO_funcs* self, PerlIO_list_t* layers, IV n,
		  const char* mode, int fd, int imode, int perm,
		  PerlIO* f, int narg, SV** args){
	PerlIO_funcs* tab = NULL;
	SV* arg;
	int i;
	const char* p;


	p = mode;
	while(*p){
		if(*p == 'r' || *p == '+'){
			Perl_croak(aTHX_ "Cannot tee for reading");
		}
		p++;
	}

	/* find the next layer that has Open() method */
	for(i = n-1; i >= 0; i--){
		tab = LayerFetch(layers, i);
		if(tab && tab->Open){
			break;
		}
	}
	assert(tab && tab->Open);


	f  = tab->Open(aTHX_ tab, layers, i,  mode,
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

static
IV
PerlIOTee_pushed(pTHX_ PerlIO* f, const char* mode, SV* arg, PerlIO_funcs* tab){
	PerlIOTee* t = PerlIOSelf(f, PerlIOTee);
	PerlIO* next = PerlIONext(f);

	IO* io;
	if(!CanWrite(next)) goto cannot_tee;

	if(SvROK(arg) && (io = GvIO(SvRV(arg)))){
		t->arg = SvREFCNT_inc_simple_NN( (SV*)io );
		t->out = IoOFP(io);

		if(!(t->out && CanWrite(t->out))){
			cannot_tee:
			SETERRNO(EBADF, SS_IVCHAN);
			return -1;
		}
	}
	else{
		PerlIO_pair_t pairs[] = { { NULL, &PL_sv_undef }, { NULL, &PL_sv_undef } };
		PerlIO_list_t layers = {
			 1, /* refcnt */
			-1, /* cur */
			 2, /* len */
			pairs /* array */
		};
		PerlIO_funcs* tab;
		if(SvPOK(arg) && SvCUR(arg) > 2){
			STRLEN len;
			const char* pv = SvPV(arg, len);
			if(*pv == '>'){
				pv++;
				len--;
				if(*pv == '>'){ /* ">> file" */
					pv++;
					len--;
					mode = "a";
				}
				else{ /* "> file" */
					mode = "w";
				}
				while(isSPACE(*pv)){
					pv++;
					len--;
				}
			}
			t->arg = newSVpvn(pv, len);
		}
		else{
			t->arg = newSVsv(arg);
		}

		if(SvROK(t->arg) && SvTYPE(SvRV(t->arg)) < SVt_PVAV){
			tab = PerlIO_find_layer(aTHX_ "scalar", sizeof("scalar"), TRUE);
			pairs[0].funcs = (PerlIO_funcs*)tab; /* const_cast */
			layers.cur = 1;
		}
		else{
			tab = (PerlIO_funcs*)&PerlIO_perlio; /* const_cast */

			pairs[0].funcs = (PerlIO_funcs*)&PerlIO_unix; /* const_cast */
			pairs[1].funcs = (PerlIO_funcs*)&PerlIO_perlio; /* const_cast */
			layers.cur = 2;

		}
		if(!mode){
			mode = "w";
		}

		PerlIO_debug("PerlIOTee: %s => %s\n", tab->name, SvPV_nolen_const(t->arg));

		t->out = tab->Open(aTHX_ tab, &layers,
			layers.cur, mode, -1, 0, 0, NULL, 1, &(t->arg));
	}
	if(!PerlIOValid(t->out)){
		return -1; /* failure */
	}

	PerlIOBase(f)->flags = PerlIOBase(t->out)->flags = PerlIOBase(next)->flags;

	return 0;
}

static
IV
PerlIOTee_popped(pTHX_ PerlIO* f){
	PerlIOTee* t = PerlIOSelf(f, PerlIOTee);

	PerlIO_close(t->out);
	t->out = NULL;

	if(t->arg && SvTYPE(t->arg) != SVt_PVIO){
		SvREFCNT_dec(t->arg);
	}
	t->arg = NULL;
	return 0;
}

static
SV*
PerlIOTee_getarg(pTHX_ PerlIO* f, CLONE_PARAMS* param, int flags){
	PerlIOTee* t = PerlIOSelf(f, PerlIOTee);

	return PerlIO_sv_dup(aTHX_ t->arg, param);
}

static
SSize_t
PerlIOTee_write(pTHX_ PerlIO* f, const void* vbuf, Size_t count){
	PerlIOTee* t = PerlIOSelf(f, PerlIOTee);
	PerlIO* next = PerlIONext(f);

	if(PerlIO_write(t->out, vbuf, count) != count){
		/* warn? */
	}

	return PerlIO_write(next, vbuf, count);
}

static
IV
PerlIOTee_flush(pTHX_ PerlIO* f){
	PerlIOTee* t = PerlIOSelf(f, PerlIOTee);
	PerlIO* next = PerlIONext(f);

	if(PerlIO_flush(t->out) != 0){
		/* warn? */
	}

	return PerlIO_flush(next);
}

static
IV
PerlIOTee_seek(pTHX_ PerlIO* f, Off_t offset, int whence){
	PerlIOTee* t = PerlIOSelf(f, PerlIOTee);
	PerlIO* next = PerlIONext(f);
	IV code;

	if((code = PerlIOTee_flush(aTHX_ f)) == 0){
		if(PerlIO_seek(t->out, offset, whence) != 0){
			/* warn? */
		}

		code = PerlIO_seek(next, offset, whence);
	}

	return code;
}

static
Off_t
PerlIOTee_tell(pTHX_ PerlIO* f){
	PerlIO* next = PerlIONext(f);

	return PerlIO_tell(next);
}


PERLIO_FUNCS_DECL(PerlIO_tee) = {
    sizeof(PerlIO_funcs),
    "tee",
    sizeof(PerlIOTee),
    PERLIO_K_BUFFERED | PERLIO_K_RAW | PERLIO_K_MULTIARG,
    PerlIOTee_pushed,
    PerlIOTee_popped,
    PerlIOTee_open,
    PerlIOBase_binmode,
    PerlIOTee_getarg,
    NULL, /* fileno */
    PerlIOBase_dup,
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


