#ifndef PERLIO_UTIL_H
#define PERLIO_UTIL_H

#define  PERLIO_FUNCS_CONST

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "perliol.h"

#define LayerFetch(layer, n) ((layer)->array[n].funcs)
#define LayerFetchSafe(layer, n) ( ((n) >= 0 && (n) < (layer)->cur) \
				? (layer)->array[n].funcs : (PerlIO_funcs*)0 )

#ifndef PERLIO_FUNCS_DECL
#define PERLIO_FUNCS_DECL(funcs) const PerlIO_funcs funcs
#define PERLIO_FUNCS_CAST(funcs) (PerlIO_funcs*)(funcs)
#endif

#include "ppport.h"

PerlIO*
PerlIOTee_teeout(pTHX_ const PerlIO* tee);

void
dump_perlio(pTHX_ PerlIO* f, int level);


extern PERLIO_FUNCS_DECL(PerlIO_flock);
extern PERLIO_FUNCS_DECL(PerlIO_creat);
extern PERLIO_FUNCS_DECL(PerlIO_excl);
extern PERLIO_FUNCS_DECL(PerlIO_tee);


#if defined(Direntry_t) && defined(HAS_READDIR)
extern PERLIO_FUNCS_DECL(PerlIO_dir);
#define define_dir_layer() PerlIO_define_layer(aTHX_ PERLIO_FUNCS_CAST(&PerlIO_dir))
#else
#define define_dir_layer() NOOP
#endif


#endif /*PERLIO_UTIL_H*/
