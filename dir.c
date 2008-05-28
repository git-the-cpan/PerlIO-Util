/*
	PerlIO::dir
*/


#include "perlioutil.h"

#define Dirp(f)   (PerlIOSelf(f, PerlIODir)->dirp)

#define DirBuf(f) (PerlIOSelf(f, PerlIODir)->buf)
#define DirBufOffset(f) (PerlIOSelf(f, PerlIODir)->offset)
#define DirBufCur(f) (PerlIOSelf(f, PerlIODir)->cur)

#if defined(FILENAME_MAX)
#	define DIR_BUFSIZ (FILENAME_MAX+1)
#else
#	define DIR_BUFSIZ 512
#endif
/*
	BUF: foobar\n@@@@@@@@@@@@@
	      ^      ^            ^
	   OFFSET   CUR        BUFSIZ
*/
typedef struct{
	struct _PerlIO base;

	DIR* dirp;

	STDCHAR buf[DIR_BUFSIZ];
	STRLEN cur;

	STRLEN offset;
} PerlIODir;

static PerlIO*
PerlIODir_open(pTHX_ PerlIO_funcs* self, PerlIO_list_t* layers, IV n,
		  const char* mode, int fd, int imode, int perm,
		  PerlIO* f, int narg, SV** args){
	PERL_UNUSED_ARG(layers);
	PERL_UNUSED_ARG(n);
	PERL_UNUSED_ARG(fd);
	PERL_UNUSED_ARG(imode);
	PERL_UNUSED_ARG(perm);
	PERL_UNUSED_ARG(narg);

	if(PerlIOValid(f)){ /* reopen */
		PerlIO_close(f);
	}
	else{
		f = PerlIO_allocate(aTHX);
	}

	switch(*mode){
		case 'r':
			if(mode[1] == '+'){
				goto permission_denied;
			}
			NOOP; /* OK */
			break;
		case IoTYPE_NUMERIC:
			SETERRNO(EINVAL, LIB_INVARG);
			return NULL;
		default:
			permission_denied:
			SETERRNO(EPERM, RMS_PRV);
			return NULL;
	}


	return PerlIO_push(aTHX_ f, self, mode, args[0]);
}

static IV
PerlIODir_pushed(pTHX_ PerlIO* f, const char* mode, SV* arg, PerlIO_funcs* tab){

	Dirp(f) = PerlDir_open(SvPV_nolen(arg));
	if(!Dirp(f)){
		return -1;
	}

	DirBufCur(f)    = 0;
	DirBufOffset(f) = 0;

	return PerlIOBase_pushed(aTHX_ f, mode, arg, tab);
}

static IV
PerlIODir_popped(pTHX_ PerlIO* f){

	if(Dirp(f)){
#ifdef VOID_CLOSEDIR
		PerlDir_close(Dirp(f));
#else
		if(PerlDir_close(Dirp(f)) < 0){
			Dirp(f) = NULL;
			SETERRNO(EBADF,RMS_IFI);
			return -1;
		}
#endif
		Dirp(f) = NULL;
	}
	return PerlIOBase_popped(aTHX_ f);
}

static IV
PerlIODir_fill(pTHX_ PerlIO* f){

#if !defined(I_DIRENT) && !defined(VMS)
	Direntry_t *readdir (DIR *);
#endif
	const Direntry_t* de = PerlDir_read(Dirp(f));

	DirBufOffset(f) = 0;
	if(de){
#ifdef DIRNAMLEN
		STRLEN len = de->d_namlen;
#else
		STRLEN len = strlen(de->d_name);
#endif

		assert(DIR_BUFSIZ > len);

		Copy(de->d_name, DirBuf(f), len, STDCHAR);

		/* add "\n" */
		DirBuf(f)[len] = '\n';

		DirBufCur(f) = len + 1;

		PerlIOBase(f)->flags |= PERLIO_F_RDBUF;

		return 0;
	}
	else{
		PerlIOBase(f)->flags &= ~PERLIO_F_RDBUF;
		PerlIOBase(f)->flags |=  PERLIO_F_EOF;
		DirBufCur(f) = 0;
		return -1;
	}
}

static STDCHAR *
PerlIODir_get_base(pTHX_ PerlIO * f){
	PERL_UNUSED_CONTEXT;

	return DirBuf(f);
}

static STDCHAR *
PerlIODir_get_ptr(pTHX_ PerlIO * f){
	PERL_UNUSED_CONTEXT;

	if(DirBufCur(f) > 0){
		return &(DirBuf(f)[0]) + DirBufOffset(f);
	}
	else{
		return NULL;
	}
}

static SSize_t
PerlIODir_get_cnt(pTHX_ PerlIO * f){
	PERL_UNUSED_CONTEXT;

	return DirBufCur(f) - DirBufOffset(f);
}

static Size_t
PerlIODir_bufsiz(pTHX_ PerlIO * f){
	PERL_UNUSED_CONTEXT;
	PERL_UNUSED_ARG(f);

	return DIR_BUFSIZ;
}

static void
PerlIODir_set_ptrcnt(pTHX_ PerlIO * f, STDCHAR * ptr, SSize_t cnt){
	PERL_UNUSED_CONTEXT;
	PERL_UNUSED_ARG(ptr);

	DirBufOffset(f) = DirBufCur(f) - cnt;
}

static IV
PerlIODir_seek(pTHX_ PerlIO* f, Off_t offset, int whence){
#if SEEK_SET == 0
#define IsSeekSet(w) (w == SEEK_SET)
#else
#define IsSeekSet(w) (w == SEEK_SET || w == 0)
#endif

	if(IsSeekSet(whence)){
		PerlDir_seek(Dirp(f), offset);
		DirBufCur(f)    = 0;
		DirBufOffset(f) = 0;
	}
	else if(offset != 0){
		SETERRNO(EINVAL, LIB_INVARG);
		return -1;
	}
	else if(whence == SEEK_END){ /* to EOF */
		while(PerlDir_read(Dirp(f))){
			NOOP;
		}
		DirBufCur(f)    = 0;
		DirBufOffset(f) = 0;
	}
	PerlIOBase(f)->flags &= ~(PERLIO_F_EOF | PERLIO_F_RDBUF);

	return 0;
}

static Off_t
PerlIODir_tell(pTHX_ PerlIO* f){
	return PerlDir_tell( Dirp(f) );
}

PERLIO_FUNCS_DECL(PerlIO_dir) = {
    sizeof(PerlIO_funcs),
    "dir",
    sizeof(PerlIODir),
    PERLIO_K_RAW | PERLIO_K_BUFFERED,
    PerlIODir_pushed,
    PerlIODir_popped,
    PerlIODir_open,
    NULL, /* binmode */
    NULL, /* getarg */
    NULL, /* fileno */
    NULL, /* dup */
    PerlIOBase_read,
    NULL, /* unread */
    NULL, /* write */
    PerlIODir_seek,
    PerlIODir_tell,
    NULL, /* close */
    NULL, /* flush */
    PerlIODir_fill,
    NULL, /* eof */
    NULL, /* error */
    NULL, /* clearerror */
    NULL, /* setlinebuf */
    PerlIODir_get_base,
    PerlIODir_bufsiz,
    PerlIODir_get_ptr,
    PerlIODir_get_cnt,
    PerlIODir_set_ptrcnt
};

