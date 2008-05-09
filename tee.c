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
	int i;


	{
		const char* p = mode;
		while(*p++){
			if(*p == 'r' || *p == '+'){
				croak("Cannot tee for reading");
			}
		}
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

	if(PerlIOArg && SvOK(PerlIOArg)){
		if(!PerlIO_push(aTHX_ f, self, mode, PerlIOArg)){
			PerlIO_close(f);
			return NULL;
		}
	}

	return f;
}

IV
PerlIOTee_pushed(pTHX_ PerlIO* f, const char* mode, SV* arg, PerlIO_funcs* tab){
	PerlIOTee* t = PerlIOSelf(f, PerlIOTee);
	PerlIO* next = PerlIONext(f);

	IO* io;
	if(!CanWrite(next)) goto cannot_tee;

	if(SvROK(arg) && (io = GvIO(SvRV(arg)))){
		t->arg = (SV*)io;
		t->out = IoOFP(io);
		if(!(t->out && CanWrite(t->out))){
			cannot_tee:
			SETERRNO(EINVAL, LIB_INVARG);
			Perl_croak(aTHX_ "Cannot tee for reading");
		}
	}
	else{
		PerlIO_pair_t pairs[] = { { NULL, &PL_sv_undef }, { NULL, &PL_sv_undef } };
		PerlIO_list_t layers = {
			1, /* refcnt */
			0, /* cur */
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
				if(*pv == '>'){ /* ">>file" */
					pv++;
					len--;
					mode = "a";
				}
				else{ /* ">file" */
					mode = "w";
				}
			}
			t->arg = newSVpvn(pv, len);
		}
		else{
			t->arg = newSVsv(arg);
			if(!mode){
				mode = "w";
			}
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

		t->out = tab->Open(aTHX_ tab, &layers,
			layers.cur, mode, -1, 0, 0, NULL, 1, &(t->arg));
	}
	if(!t->out && ckWARN(WARN_IO)){
		Perl_warner(aTHX_ packWARN(WARN_IO),
			"Cannot open '%s': %s",
			SvOK(t->arg) ? SvPV_nolen(t->arg) : "",
			Strerror(errno));
		return -1;
	}

	PerlIOBase(f)->flags = PerlIOBase(t->out)->flags = PerlIOBase(next)->flags;

	return 0;
}

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

SV*
PerlIOTee_getarg(pTHX_ PerlIO* f, CLONE_PARAMS* param, int flags){
	PerlIOTee* t = PerlIOSelf(f, PerlIOTee);

	return PerlIO_sv_dup(aTHX_ t->arg, param);
}

SSize_t
PerlIOTee_write(pTHX_ PerlIO* f, const void* vbuf, Size_t count){
	PerlIOTee* t = PerlIOSelf(f, PerlIOTee);
	PerlIO* next = PerlIONext(f);

	if(PerlIO_write(t->out, vbuf, count) != count){
		/* warn? */
	}

	return PerlIO_write(next, vbuf, count);
}

IV
PerlIOTee_flush(pTHX_ PerlIO* f){
	PerlIOTee* t = PerlIOSelf(f, PerlIOTee);
	PerlIO* next = PerlIONext(f);

	if(PerlIO_flush(t->out) != 0){
		/* warn? */
	}

	return PerlIO_flush(next);
}

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
    PerlIOBase_fileno,
    PerlIOBase_dup,
    NULL, /* read */
    NULL, /* unread */
    PerlIOTee_write,
    NULL, /* seek */
    PerlIOTee_tell,
    NULL, /* close */
    PerlIOTee_flush,
    NULL, /* fill */
    NULL, /* eof */
    PerlIOBase_error,
    PerlIOBase_clearerr,
    PerlIOBase_setlinebuf,
    NULL, /* get_base */
    NULL, /* bufsiz */
    NULL, /* get_ptr */
    NULL, /* get_cnt */
    NULL, /* set_ptrcnt */
};


