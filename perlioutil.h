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

#endif
