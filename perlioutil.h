#ifndef PERLIO_UTIL_H
#define PERLIO_UTIL_H

#define  PERLIO_FUNCS_CONST

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "perliol.h"

#define LayerFetch(layer, n) ((layer)->array[n].funcs)
#define LayerFetchSafe(layer, n) ( ((n) >= 0 && (n) < (layer)->cur) \
				? (layer)->array[n].funcs : PERLIO_FUNCS_CAST(&PerlIO_unix) )

#ifndef PERLIO_FUNCS_DECL
#define PERLIO_FUNCS_DECL(funcs) const PerlIO_funcs funcs
#define PERLIO_FUNCS_CAST(funcs) (PerlIO_funcs*)(funcs)
#endif

#include "ppport.h"

#define IOLflag(f, flag)     (PerlIOBase((f))->flags & (flag))
#define IOLflag_on(f, flag)  (PerlIOBase((f))->flags |= (flag))
#define IOLflag_off(f, flag) (PerlIOBase((f))->flags &= ~(flag));


PerlIO*
PerlIOTee_teeout(pTHX_ const PerlIO* tee);

void
dump_perlio(pTHX_ PerlIO* f, int level);


extern PERLIO_FUNCS_DECL(PerlIO_flock);
extern PERLIO_FUNCS_DECL(PerlIO_creat);
extern PERLIO_FUNCS_DECL(PerlIO_excl);
extern PERLIO_FUNCS_DECL(PerlIO_tee);
extern PERLIO_FUNCS_DECL(PerlIO_dir);
extern PERLIO_FUNCS_DECL(PerlIO_reverse);


#endif /*PERLIO_UTIL_H*/
