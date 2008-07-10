/*
	PerlIO-Util/Util.xs
*/

#include "perlioutil.h"


PerlIO*
PerlIOUtil_openn(pTHX_ PerlIO_funcs* force_tab, PerlIO_list_t* layers, IV n,
		const char* mode, int fd, int imode, int perm,
		PerlIO* f, int narg, SV** args){
	PerlIO_funcs* tab = NULL;

	IV i = n;

	while(--i >= 0){ /* find a layer with Open() */
		tab = LayerFetch(layers, i);
		if(tab && tab->Open){
			break;
		}
	}

	if(force_tab){
		tab = force_tab;
	}

	if(tab && tab->Open){
		f = tab->Open(aTHX_ tab, layers, i,  mode,
				fd, imode, perm, f, narg, args);

		/* apply above layers
		   e.g. [ :unix :perlio :utf8 :creat ]
		                        ~~~~~        
		*/

		if(f && ++i < n){
			if(PerlIO_apply_layera(aTHX_ f, mode, layers, i, n) != 0){
				PerlIO_close(f);
				f = NULL;
			}
		}

	}
	else{
		SETERRNO(EINVAL, LIB_INVARG);
	}

	return f;
}

#define PutFlag(c) do{\
		if(PerlIOBase(f)->flags & (PERLIO_F_##c)){\
			sv_catpvf(sv, " %s", #c);\
		}\
	}while(0)

SV*
dump_perlio(pTHX_ PerlIO* f, int level){
	SV* sv = newSVpvf("PerlIO 0x%p\n", f);

	if(!PerlIOValid(f)){
		int i;
		for(i = 0; i <= level; i++) sv_catpvs(sv, "  ");

		sv_catpvs(sv, "(Invalid filehandle)\n");
	}

	while(PerlIOValid(f)){
		int i;
		for(i = 0; i <= level; i++) sv_catpv(sv, "  ");

		sv_catpvf(sv, "0x%p:%s(%d)",
			*f, PerlIOBase(f)->tab->name,
			(int)PerlIO_fileno(f));
		PutFlag(EOF);
		PutFlag(CANWRITE);
		PutFlag(CANREAD);
		PutFlag(ERROR);
		PutFlag(TRUNCATE);
		PutFlag(APPEND);
		PutFlag(CRLF);
		PutFlag(UTF8);
		PutFlag(UNBUF);
		PutFlag(WRBUF);
		PutFlag(RDBUF);
		PutFlag(LINEBUF);
		PutFlag(TEMP);
		PutFlag(OPEN);
		PutFlag(FASTGETS);
		PutFlag(TTY);
		PutFlag(NOTREG);
		sv_catpvs(sv, "\n");

		if( strEQ(PerlIOBase(f)->tab->name, "tee") ){
			PerlIO* teeout = PerlIOTee_teeout(aTHX_ f);
			SV* t = dump_perlio(aTHX_ teeout, level+1);

			sv_catsv(sv, t);
			SvREFCNT_dec(t);
		}

		f = PerlIONext(f);
	}

	return sv;
}


MODULE = PerlIO::Util		PACKAGE = PerlIO::Util		

PROTOTYPES: DISABLE

BOOT:
	PerlIO_define_layer(aTHX_ PERLIO_FUNCS_CAST(&PerlIO_flock));
	PerlIO_define_layer(aTHX_ PERLIO_FUNCS_CAST(&PerlIO_creat));
	PerlIO_define_layer(aTHX_ PERLIO_FUNCS_CAST(&PerlIO_excl));
	PerlIO_define_layer(aTHX_ PERLIO_FUNCS_CAST(&PerlIO_tee));
	PerlIO_define_layer(aTHX_ PERLIO_FUNCS_CAST(&PerlIO_dir));
	PerlIO_define_layer(aTHX_ PERLIO_FUNCS_CAST(&PerlIO_reverse));
	PerlIO_define_layer(aTHX_ PERLIO_FUNCS_CAST(&PerlIO_fse));

void
known_layers(...)
PREINIT:
	const PerlIO_list_t* layers = PL_known_layers;
	int i;
PPCODE:
	EXTEND(SP, layers->cur);
	for(i = 0; i < layers->cur; i++){
		SV* name = newSVpv( LayerFetch(layers, i)->name, 0);
		PUSHs( sv_2mortal(name) );
	}
	XSRETURN(layers->cur);

SV*
fse(...)
CODE:
	RETVAL = PerlIOFSE_get_fse(aTHX);
	SvREFCNT_inc_simple_void_NN(RETVAL);
	if(items > 1){
		sv_setsv(RETVAL, ST(1));
	}
OUTPUT:
	RETVAL


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
	if(laypv[0] == ':'){ /* ignore a layer prefix */
		laypv++;
		laylen--;
	}
	tab = PerlIO_find_layer(aTHX_ laypv, laylen, TRUE);
	if(tab){
		if(!PerlIO_push(aTHX_ filehandle, tab, Nullch, arg ? arg : &PL_sv_undef)){
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
	XSRETURN(1); /* returns self */

void
pop_layer(filehandle)
	PerlIO* filehandle
PREINIT:
	const char* popped_layer = Nullch;
PPCODE:
	if(!PerlIOValid(filehandle)) XSRETURN_EMPTY;
	popped_layer = PerlIOBase(filehandle)->tab->name;

	PerlIO_flush(filehandle);
	PerlIO_pop(aTHX_ filehandle);

	if(GIMME_V != G_VOID){
		XSRETURN_PV(popped_layer);
	}


SV*
_dump(f)
	PerlIO* f
CODE:
	RETVAL = dump_perlio(aTHX_ f, 0);
OUTPUT:
	RETVAL

