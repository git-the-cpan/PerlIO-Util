/*
	PerlIO-Util/Util.xs
*/

#include "perlioutil.h"



#define PutFlag(c) do{\
		if(PerlIOBase(f)->flags & (PERLIO_F_##c)){\
			printf(" %s", #c);\
		}\
	}while(0)

void
dump_perlio(pTHX_ PerlIO* f, int level){
	if(!PerlIOValid(f)){
		int i;
		for(i = 0; i < level; i++) printf("\t");

		printf("(Invalid filehandle)");
	}

	while(PerlIOValid(f)){
		int i;
		for(i = 0; i < level; i++) printf("\t");

		printf(":%s (%p) flags=0x%lx",
			PerlIOBase(f)->tab->name, f, (unsigned long)PerlIOBase(f)->flags);
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
		printf("\n");

		if( strEQ(PerlIOBase(f)->tab->name, "tee") ){
			PerlIO* teeout = PerlIOTee_teeout(aTHX_ f);

			dump_perlio(aTHX_ teeout, level+1);
		}

		f = PerlIONext(f);
	}
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

void
_dump(f)
	PerlIO* f
CODE:
	/* this function is only for debugging */
	dump_perlio(aTHX_ f, 0);

=for debug

#define XF(c) do{\
		if(flags & (PERLIO_F_##c)){\
			n++;\
			mXPUSHp( #c, sizeof( #c ) - 1 );\
		}\
	}while(0)


void
flags(filehandle)
	PerlIO* filehandle
PREINIT:
	U32 flags;
	IV n = 0;
PPCODE:
	if(!PerlIOValid(filehandle)) XSRETURN_EMPTY;

	flags = PerlIOBase(filehandle)->flags;

	XF(EOF);
	XF(CANWRITE);
	XF(CANREAD);
	XF(ERROR);
	XF(TRUNCATE);
	XF(APPEND);
	XF(CRLF);
	XF(UTF8);
	XF(UNBUF);
	XF(WRBUF);
	XF(RDBUF);
	XF(LINEBUF);
	XF(TEMP);
	XF(OPEN);
	XF(FASTGETS);
	XF(TTY);
	XF(NOTREG);

	XSRETURN(n);


=for debug

void
getarg(filehandle)
	PerlIO* filehandle
PREINIT:
	PerlIO_funcs* tab;
PPCODE:
	tab = PerlIOBase(filehandle)->tab;
	if(tab->Getarg){
		ST(0) = tab->Getarg(aTHX_ filehandle, NULL, 0);
		sv_2mortal(ST(0));
		XSRETURN(1);
	}

=cut
