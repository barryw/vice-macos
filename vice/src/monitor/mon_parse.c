/* A Bison parser, made by GNU Bison 2.3.  */

/* Skeleton implementation for Bison's Yacc-like parsers in C

   Copyright (C) 1984, 1989, 1990, 2000, 2001, 2002, 2003, 2004, 2005, 2006
   Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* C LALR(1) parser skeleton written by Richard Stallman, by
   simplifying the original so-called "semantic" parser.  */

/* All symbols defined below should begin with yy or YY, to avoid
   infringing on user name space.  This should be done even for local
   variables, as they might otherwise be expanded by user macros.
   There are some unavoidable exceptions within include files to
   define necessary library symbols; they are noted "INFRINGES ON
   USER NAME SPACE" below.  */

/* Identify Bison output.  */
#define YYBISON 1

/* Bison version.  */
#define YYBISON_VERSION "2.3"

/* Skeleton name.  */
#define YYSKELETON_NAME "yacc.c"

/* Pure parsers.  */
#define YYPURE 0

/* Using locations.  */
#define YYLSP_NEEDED 0



/* Tokens.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
   /* Put the tokens into the symbol table, so that GDB and other debuggers
      know about them.  */
   enum yytokentype {
     H_NUMBER = 258,
     D_NUMBER = 259,
     O_NUMBER = 260,
     B_NUMBER = 261,
     CONVERT_OP = 262,
     B_DATA = 263,
     H_RANGE_GUESS = 264,
     D_NUMBER_GUESS = 265,
     O_NUMBER_GUESS = 266,
     B_NUMBER_GUESS = 267,
     BAD_CMD = 268,
     MEM_OP = 269,
     IF = 270,
     MEM_COMP = 271,
     MEM_DISK8 = 272,
     MEM_DISK9 = 273,
     MEM_DISK10 = 274,
     MEM_DISK11 = 275,
     EQUALS = 276,
     TRAIL = 277,
     CMD_SEP = 278,
     LABEL_ASGN_COMMENT = 279,
     CMD_LOG = 280,
     CMD_LOGNAME = 281,
     CMD_SIDEFX = 282,
     CMD_DUMMY = 283,
     CMD_RETURN = 284,
     CMD_BLOCK_READ = 285,
     CMD_BLOCK_WRITE = 286,
     CMD_UP = 287,
     CMD_DOWN = 288,
     CMD_LOAD = 289,
     CMD_BASICLOAD = 290,
     CMD_SAVE = 291,
     CMD_VERIFY = 292,
     CMD_BVERIFY = 293,
     CMD_IGNORE = 294,
     CMD_HUNT = 295,
     CMD_FILL = 296,
     CMD_MOVE = 297,
     CMD_GOTO = 298,
     CMD_REGISTERS = 299,
     CMD_READSPACE = 300,
     CMD_WRITESPACE = 301,
     CMD_RADIX = 302,
     CMD_MEM_DISPLAY = 303,
     CMD_BREAK = 304,
     CMD_TRACE = 305,
     CMD_IO = 306,
     CMD_BRMON = 307,
     CMD_COMPARE = 308,
     CMD_DUMP = 309,
     CMD_UNDUMP = 310,
     CMD_EXIT = 311,
     CMD_DELETE = 312,
     CMD_CONDITION = 313,
     CMD_COMMAND = 314,
     CMD_ASSEMBLE = 315,
     CMD_DISASSEMBLE = 316,
     CMD_NEXT = 317,
     CMD_STEP = 318,
     CMD_PRINT = 319,
     CMD_DEVICE = 320,
     CMD_HELP = 321,
     CMD_WATCH = 322,
     CMD_DISK = 323,
     CMD_QUIT = 324,
     CMD_CHDIR = 325,
     CMD_BANK = 326,
     CMD_LOAD_LABELS = 327,
     CMD_SAVE_LABELS = 328,
     CMD_ADD_LABEL = 329,
     CMD_DEL_LABEL = 330,
     CMD_SHOW_LABELS = 331,
     CMD_CLEAR_LABELS = 332,
     CMD_RECORD = 333,
     CMD_MON_STOP = 334,
     CMD_PLAYBACK = 335,
     CMD_CHAR_DISPLAY = 336,
     CMD_SPRITE_DISPLAY = 337,
     CMD_TEXT_DISPLAY = 338,
     CMD_SCREENCODE_DISPLAY = 339,
     CMD_ENTER_DATA = 340,
     CMD_ENTER_BIN_DATA = 341,
     CMD_KEYBUF = 342,
     CMD_BLOAD = 343,
     CMD_BSAVE = 344,
     CMD_SCREEN = 345,
     CMD_UNTIL = 346,
     CMD_CPU = 347,
     CMD_YYDEBUG = 348,
     CMD_BACKTRACE = 349,
     CMD_SCREENSHOT = 350,
     CMD_PWD = 351,
     CMD_DIR = 352,
     CMD_MKDIR = 353,
     CMD_RMDIR = 354,
     CMD_RESOURCE_GET = 355,
     CMD_RESOURCE_SET = 356,
     CMD_LOAD_RESOURCES = 357,
     CMD_SAVE_RESOURCES = 358,
     CMD_ATTACH = 359,
     CMD_DETACH = 360,
     CMD_MON_RESET = 361,
     CMD_TAPECTRL = 362,
     CMD_TAPEOFFS = 363,
     CMD_CARTFREEZE = 364,
     CMD_UPDB = 365,
     CMD_JPDB = 366,
     CMD_CPUHISTORY = 367,
     CMD_MEMMAPZAP = 368,
     CMD_MEMMAPSHOW = 369,
     CMD_MEMMAPSAVE = 370,
     CMD_COMMENT = 371,
     CMD_LIST = 372,
     CMD_STOPWATCH = 373,
     RESET = 374,
     CMD_EXPORT = 375,
     CMD_AUTOSTART = 376,
     CMD_AUTOLOAD = 377,
     CMD_MAINCPU_TRACE = 378,
     CMD_WARP = 379,
     CMD_PROFILE = 380,
     FLAT = 381,
     GRAPH = 382,
     FUNC = 383,
     DEPTH = 384,
     DISASS = 385,
     PROFILE_CONTEXT = 386,
     CLEAR = 387,
     CMD_LABEL_ASGN = 388,
     L_PAREN = 389,
     R_PAREN = 390,
     ARG_IMMEDIATE = 391,
     REG_A = 392,
     REG_X = 393,
     REG_Y = 394,
     COMMA = 395,
     INST_SEP = 396,
     L_BRACKET = 397,
     R_BRACKET = 398,
     LESS_THAN = 399,
     REG_U = 400,
     REG_S = 401,
     REG_PC = 402,
     REG_PCR = 403,
     REG_B = 404,
     REG_C = 405,
     REG_D = 406,
     REG_E = 407,
     REG_H = 408,
     REG_L = 409,
     REG_AF = 410,
     REG_BC = 411,
     REG_DE = 412,
     REG_HL = 413,
     REG_IX = 414,
     REG_IY = 415,
     REG_SP = 416,
     REG_IXH = 417,
     REG_IXL = 418,
     REG_IYH = 419,
     REG_IYL = 420,
     PLUS = 421,
     MINUS = 422,
     STRING = 423,
     FILENAME = 424,
     R_O_L = 425,
     R_O_L_Q = 426,
     OPCODE = 427,
     LABEL = 428,
     BANKNAME = 429,
     CPUTYPE = 430,
     MON_REGISTER = 431,
     COND_OP = 432,
     RADIX_TYPE = 433,
     INPUT_SPEC = 434,
     CMD_CHECKPT_ON = 435,
     CMD_CHECKPT_OFF = 436,
     TOGGLE = 437,
     MASK = 438
   };
#endif
/* Tokens.  */
#define H_NUMBER 258
#define D_NUMBER 259
#define O_NUMBER 260
#define B_NUMBER 261
#define CONVERT_OP 262
#define B_DATA 263
#define H_RANGE_GUESS 264
#define D_NUMBER_GUESS 265
#define O_NUMBER_GUESS 266
#define B_NUMBER_GUESS 267
#define BAD_CMD 268
#define MEM_OP 269
#define IF 270
#define MEM_COMP 271
#define MEM_DISK8 272
#define MEM_DISK9 273
#define MEM_DISK10 274
#define MEM_DISK11 275
#define EQUALS 276
#define TRAIL 277
#define CMD_SEP 278
#define LABEL_ASGN_COMMENT 279
#define CMD_LOG 280
#define CMD_LOGNAME 281
#define CMD_SIDEFX 282
#define CMD_DUMMY 283
#define CMD_RETURN 284
#define CMD_BLOCK_READ 285
#define CMD_BLOCK_WRITE 286
#define CMD_UP 287
#define CMD_DOWN 288
#define CMD_LOAD 289
#define CMD_BASICLOAD 290
#define CMD_SAVE 291
#define CMD_VERIFY 292
#define CMD_BVERIFY 293
#define CMD_IGNORE 294
#define CMD_HUNT 295
#define CMD_FILL 296
#define CMD_MOVE 297
#define CMD_GOTO 298
#define CMD_REGISTERS 299
#define CMD_READSPACE 300
#define CMD_WRITESPACE 301
#define CMD_RADIX 302
#define CMD_MEM_DISPLAY 303
#define CMD_BREAK 304
#define CMD_TRACE 305
#define CMD_IO 306
#define CMD_BRMON 307
#define CMD_COMPARE 308
#define CMD_DUMP 309
#define CMD_UNDUMP 310
#define CMD_EXIT 311
#define CMD_DELETE 312
#define CMD_CONDITION 313
#define CMD_COMMAND 314
#define CMD_ASSEMBLE 315
#define CMD_DISASSEMBLE 316
#define CMD_NEXT 317
#define CMD_STEP 318
#define CMD_PRINT 319
#define CMD_DEVICE 320
#define CMD_HELP 321
#define CMD_WATCH 322
#define CMD_DISK 323
#define CMD_QUIT 324
#define CMD_CHDIR 325
#define CMD_BANK 326
#define CMD_LOAD_LABELS 327
#define CMD_SAVE_LABELS 328
#define CMD_ADD_LABEL 329
#define CMD_DEL_LABEL 330
#define CMD_SHOW_LABELS 331
#define CMD_CLEAR_LABELS 332
#define CMD_RECORD 333
#define CMD_MON_STOP 334
#define CMD_PLAYBACK 335
#define CMD_CHAR_DISPLAY 336
#define CMD_SPRITE_DISPLAY 337
#define CMD_TEXT_DISPLAY 338
#define CMD_SCREENCODE_DISPLAY 339
#define CMD_ENTER_DATA 340
#define CMD_ENTER_BIN_DATA 341
#define CMD_KEYBUF 342
#define CMD_BLOAD 343
#define CMD_BSAVE 344
#define CMD_SCREEN 345
#define CMD_UNTIL 346
#define CMD_CPU 347
#define CMD_YYDEBUG 348
#define CMD_BACKTRACE 349
#define CMD_SCREENSHOT 350
#define CMD_PWD 351
#define CMD_DIR 352
#define CMD_MKDIR 353
#define CMD_RMDIR 354
#define CMD_RESOURCE_GET 355
#define CMD_RESOURCE_SET 356
#define CMD_LOAD_RESOURCES 357
#define CMD_SAVE_RESOURCES 358
#define CMD_ATTACH 359
#define CMD_DETACH 360
#define CMD_MON_RESET 361
#define CMD_TAPECTRL 362
#define CMD_TAPEOFFS 363
#define CMD_CARTFREEZE 364
#define CMD_UPDB 365
#define CMD_JPDB 366
#define CMD_CPUHISTORY 367
#define CMD_MEMMAPZAP 368
#define CMD_MEMMAPSHOW 369
#define CMD_MEMMAPSAVE 370
#define CMD_COMMENT 371
#define CMD_LIST 372
#define CMD_STOPWATCH 373
#define RESET 374
#define CMD_EXPORT 375
#define CMD_AUTOSTART 376
#define CMD_AUTOLOAD 377
#define CMD_MAINCPU_TRACE 378
#define CMD_WARP 379
#define CMD_PROFILE 380
#define FLAT 381
#define GRAPH 382
#define FUNC 383
#define DEPTH 384
#define DISASS 385
#define PROFILE_CONTEXT 386
#define CLEAR 387
#define CMD_LABEL_ASGN 388
#define L_PAREN 389
#define R_PAREN 390
#define ARG_IMMEDIATE 391
#define REG_A 392
#define REG_X 393
#define REG_Y 394
#define COMMA 395
#define INST_SEP 396
#define L_BRACKET 397
#define R_BRACKET 398
#define LESS_THAN 399
#define REG_U 400
#define REG_S 401
#define REG_PC 402
#define REG_PCR 403
#define REG_B 404
#define REG_C 405
#define REG_D 406
#define REG_E 407
#define REG_H 408
#define REG_L 409
#define REG_AF 410
#define REG_BC 411
#define REG_DE 412
#define REG_HL 413
#define REG_IX 414
#define REG_IY 415
#define REG_SP 416
#define REG_IXH 417
#define REG_IXL 418
#define REG_IYH 419
#define REG_IYL 420
#define PLUS 421
#define MINUS 422
#define STRING 423
#define FILENAME 424
#define R_O_L 425
#define R_O_L_Q 426
#define OPCODE 427
#define LABEL 428
#define BANKNAME 429
#define CPUTYPE 430
#define MON_REGISTER 431
#define COND_OP 432
#define RADIX_TYPE 433
#define INPUT_SPEC 434
#define CMD_CHECKPT_ON 435
#define CMD_CHECKPT_OFF 436
#define TOGGLE 437
#define MASK 438




/* Copy the first part of user declarations.  */
#line 1 "mon_parse.y"

/* -*- C -*-
 *
 * mon_parse.y - Parser for the VICE built-in monitor.
 *
 * Written by
 *  Daniel Sladic <sladic@eecg.toronto.edu>
 *  Andreas Boose <viceteam@t-online.de>
 *  Thomas Giesel <skoe@directbox.com>
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
 *  02111-1307  USA.
 *
 */

#include "vice.h"

#ifdef __GNUC__
#undef alloca
#define        alloca(n)       __builtin_alloca (n)
#else /* not __GNUC__ */
#ifdef HAVE_ALLOCA_H
#include <alloca.h>
#else  /* Not HAVE_ALLOCA_H  */
char *alloca();
#endif /* HAVE_ALLOCA_H.  */
#endif /* __GNUC__ */

#include <assert.h>
#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "asm.h"
#include "console.h"
#include "drive.h"
#include "interrupt.h"
#include "lib.h"
#include "machine.h"
#include "mon_breakpoint.h"
#include "mon_command.h"
#include "mon_disassemble.h"
#include "mon_drive.h"
#include "mon_file.h"
#include "mon_memmap.h"
#include "mon_memory.h"
#include "mon_register.h"
#include "mon_util.h"
#include "montypes.h"
#include "tapeport.h"
#include "resources.h"
#include "types.h"
#include "uimon.h"
#include "vsync.h"
#include "mon_profile.h"

#define join_ints(x,y) (LO16_TO_HI16(x)|y)
#define separate_int1(x) (HI16_TO_LO16(x))
#define separate_int2(x) (LO16(x))

static int yyerror(char *s);
static int temp;
static int resolve_datatype(unsigned guess_type, const char *num);
static int resolve_range(enum t_memspace memspace, MON_ADDR range[2],
                         const char *num);

/* Defined in the lexer */
extern int new_cmd, opt_asm;
extern int cur_len, last_len;

void free_buffer(void);
void make_buffer(char *str);
int yylex(void);

void set_yydebug(int val);

#define ERR_ILLEGAL_INPUT 1     /* Generic error as returned by yacc.  */
#define ERR_RANGE_BAD_START 2
#define ERR_RANGE_BAD_END 3
#define ERR_BAD_CMD 4
#define ERR_EXPECT_CHECKNUM 5
#define ERR_EXPECT_END_CMD 6
#define ERR_MISSING_CLOSE_PAREN 7
#define ERR_INCOMPLETE_COND_OP 8
#define ERR_EXPECT_FILENAME 9
#define ERR_ADDR_TOO_BIG 10
#define ERR_IMM_TOO_BIG 11
#define ERR_EXPECT_STRING 12
#define ERR_UNDEFINED_LABEL 13
#define ERR_EXPECT_DEVICE_NUM 14
#define ERR_EXPECT_ADDRESS 15
#define ERR_INVALID_REGISTER 16

#define BAD_ADDR (new_addr(e_invalid_space, 0))
#define CHECK_ADDR(x) ((x) == addr_mask(x))

/* set to YYDEBUG 1 to get parser debugging via "yydebug" command, requires to
   set_yydebug(1) in monitor.c:monitor_init */
#ifdef DEBUG
#define YYDEBUG 1
#else
#define YYDEBUG 0
#endif



/* Enabling traces.  */
#ifndef YYDEBUG
# define YYDEBUG 1
#endif

/* Enabling verbose error messages.  */
#ifdef YYERROR_VERBOSE
# undef YYERROR_VERBOSE
# define YYERROR_VERBOSE 1
#else
# define YYERROR_VERBOSE 0
#endif

/* Enabling the token table.  */
#ifndef YYTOKEN_TABLE
# define YYTOKEN_TABLE 0
#endif

#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
typedef union YYSTYPE
#line 123 "mon_parse.y"
{
    MON_ADDR a;
    MON_ADDR range[2];
    int i;
    REG_ID reg;
    CONDITIONAL cond_op;
    cond_node_t *cond_node;
    RADIXTYPE rt;
    ACTION action;
    char *str;
    asm_mode_addr_info_t mode;
}
/* Line 193 of yacc.c.  */
#line 597 "mon_parse.c"
	YYSTYPE;
# define yystype YYSTYPE /* obsolescent; will be withdrawn */
# define YYSTYPE_IS_DECLARED 1
# define YYSTYPE_IS_TRIVIAL 1
#endif



/* Copy the second part of user declarations.  */


/* Line 216 of yacc.c.  */
#line 610 "mon_parse.c"

#ifdef short
# undef short
#endif

#ifdef YYTYPE_UINT8
typedef YYTYPE_UINT8 yytype_uint8;
#else
typedef unsigned char yytype_uint8;
#endif

#ifdef YYTYPE_INT8
typedef YYTYPE_INT8 yytype_int8;
#elif (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
typedef signed char yytype_int8;
#else
typedef short int yytype_int8;
#endif

#ifdef YYTYPE_UINT16
typedef YYTYPE_UINT16 yytype_uint16;
#else
typedef unsigned short int yytype_uint16;
#endif

#ifdef YYTYPE_INT16
typedef YYTYPE_INT16 yytype_int16;
#else
typedef short int yytype_int16;
#endif

#ifndef YYSIZE_T
# ifdef __SIZE_TYPE__
#  define YYSIZE_T __SIZE_TYPE__
# elif defined size_t
#  define YYSIZE_T size_t
# elif ! defined YYSIZE_T && (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
#  include <stddef.h> /* INFRINGES ON USER NAME SPACE */
#  define YYSIZE_T size_t
# else
#  define YYSIZE_T unsigned int
# endif
#endif

#define YYSIZE_MAXIMUM ((YYSIZE_T) -1)

#ifndef YY_
# if defined YYENABLE_NLS && YYENABLE_NLS
#  if ENABLE_NLS
#   include <libintl.h> /* INFRINGES ON USER NAME SPACE */
#   define YY_(msgid) dgettext ("bison-runtime", msgid)
#  endif
# endif
# ifndef YY_
#  define YY_(msgid) msgid
# endif
#endif

/* Suppress unused-variable warnings by "using" E.  */
#if ! defined lint || defined __GNUC__
# define YYUSE(e) ((void) (e))
#else
# define YYUSE(e) /* empty */
#endif

/* Identity function, used to suppress warnings about constant conditions.  */
#ifndef lint
# define YYID(n) (n)
#else
#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
static int
YYID (int i)
#else
static int
YYID (i)
    int i;
#endif
{
  return i;
}
#endif

#if ! defined yyoverflow || YYERROR_VERBOSE

/* The parser invokes alloca or malloc; define the necessary symbols.  */

# ifdef YYSTACK_USE_ALLOCA
#  if YYSTACK_USE_ALLOCA
#   ifdef __GNUC__
#    define YYSTACK_ALLOC __builtin_alloca
#   elif defined __BUILTIN_VA_ARG_INCR
#    include <alloca.h> /* INFRINGES ON USER NAME SPACE */
#   elif defined _AIX
#    define YYSTACK_ALLOC __alloca
#   elif defined _MSC_VER
#    include <malloc.h> /* INFRINGES ON USER NAME SPACE */
#    define alloca _alloca
#   else
#    define YYSTACK_ALLOC alloca
#    if ! defined _ALLOCA_H && ! defined _STDLIB_H && (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
#     include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
#     ifndef _STDLIB_H
#      define _STDLIB_H 1
#     endif
#    endif
#   endif
#  endif
# endif

# ifdef YYSTACK_ALLOC
   /* Pacify GCC's `empty if-body' warning.  */
#  define YYSTACK_FREE(Ptr) do { /* empty */; } while (YYID (0))
#  ifndef YYSTACK_ALLOC_MAXIMUM
    /* The OS might guarantee only one guard page at the bottom of the stack,
       and a page size can be as small as 4096 bytes.  So we cannot safely
       invoke alloca (N) if N exceeds 4096.  Use a slightly smaller number
       to allow for a few compiler-allocated temporary stack slots.  */
#   define YYSTACK_ALLOC_MAXIMUM 4032 /* reasonable circa 2006 */
#  endif
# else
#  define YYSTACK_ALLOC YYMALLOC
#  define YYSTACK_FREE YYFREE
#  ifndef YYSTACK_ALLOC_MAXIMUM
#   define YYSTACK_ALLOC_MAXIMUM YYSIZE_MAXIMUM
#  endif
#  if (defined __cplusplus && ! defined _STDLIB_H \
       && ! ((defined YYMALLOC || defined malloc) \
	     && (defined YYFREE || defined free)))
#   include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
#   ifndef _STDLIB_H
#    define _STDLIB_H 1
#   endif
#  endif
#  ifndef YYMALLOC
#   define YYMALLOC malloc
#   if ! defined malloc && ! defined _STDLIB_H && (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
void *malloc (YYSIZE_T); /* INFRINGES ON USER NAME SPACE */
#   endif
#  endif
#  ifndef YYFREE
#   define YYFREE free
#   if ! defined free && ! defined _STDLIB_H && (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
void free (void *); /* INFRINGES ON USER NAME SPACE */
#   endif
#  endif
# endif
#endif /* ! defined yyoverflow || YYERROR_VERBOSE */


#if (! defined yyoverflow \
     && (! defined __cplusplus \
	 || (defined YYSTYPE_IS_TRIVIAL && YYSTYPE_IS_TRIVIAL)))

/* A type that is properly aligned for any stack member.  */
union yyalloc
{
  yytype_int16 yyss;
  YYSTYPE yyvs;
  };

/* The size of the maximum gap between one aligned stack and the next.  */
# define YYSTACK_GAP_MAXIMUM (sizeof (union yyalloc) - 1)

/* The size of an array large to enough to hold all stacks, each with
   N elements.  */
# define YYSTACK_BYTES(N) \
     ((N) * (sizeof (yytype_int16) + sizeof (YYSTYPE)) \
      + YYSTACK_GAP_MAXIMUM)

/* Copy COUNT objects from FROM to TO.  The source and destination do
   not overlap.  */
# ifndef YYCOPY
#  if defined __GNUC__ && 1 < __GNUC__
#   define YYCOPY(To, From, Count) \
      __builtin_memcpy (To, From, (Count) * sizeof (*(From)))
#  else
#   define YYCOPY(To, From, Count)		\
      do					\
	{					\
	  YYSIZE_T yyi;				\
	  for (yyi = 0; yyi < (Count); yyi++)	\
	    (To)[yyi] = (From)[yyi];		\
	}					\
      while (YYID (0))
#  endif
# endif

/* Relocate STACK from its old location to the new one.  The
   local variables YYSIZE and YYSTACKSIZE give the old and new number of
   elements in the stack, and YYPTR gives the new location of the
   stack.  Advance YYPTR to a properly aligned location for the next
   stack.  */
# define YYSTACK_RELOCATE(Stack)					\
    do									\
      {									\
	YYSIZE_T yynewbytes;						\
	YYCOPY (&yyptr->Stack, Stack, yysize);				\
	Stack = &yyptr->Stack;						\
	yynewbytes = yystacksize * sizeof (*Stack) + YYSTACK_GAP_MAXIMUM; \
	yyptr += yynewbytes / sizeof (*yyptr);				\
      }									\
    while (YYID (0))

#endif

/* YYFINAL -- State number of the termination state.  */
#define YYFINAL  352
/* YYLAST -- Last index in YYTABLE.  */
#define YYLAST   1981

/* YYNTOKENS -- Number of terminals.  */
#define YYNTOKENS  192
/* YYNNTS -- Number of nonterminals.  */
#define YYNNTS  58
/* YYNRULES -- Number of rules.  */
#define YYNRULES  360
/* YYNRULES -- Number of states.  */
#define YYNSTATES  738

/* YYTRANSLATE(YYLEX) -- Bison symbol number corresponding to YYLEX.  */
#define YYUNDEFTOK  2
#define YYMAXUTOK   438

#define YYTRANSLATE(YYX)						\
  ((unsigned int) (YYX) <= YYMAXUTOK ? yytranslate[YYX] : YYUNDEFTOK)

/* YYTRANSLATE[YYLEX] -- Bison symbol number corresponding to YYLEX.  */
static const yytype_uint8 yytranslate[] =
{
       0,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
     188,   189,   186,   184,     2,   185,     2,   187,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,   191,     2,
       2,     2,     2,     2,   190,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     1,     2,     3,     4,
       5,     6,     7,     8,     9,    10,    11,    12,    13,    14,
      15,    16,    17,    18,    19,    20,    21,    22,    23,    24,
      25,    26,    27,    28,    29,    30,    31,    32,    33,    34,
      35,    36,    37,    38,    39,    40,    41,    42,    43,    44,
      45,    46,    47,    48,    49,    50,    51,    52,    53,    54,
      55,    56,    57,    58,    59,    60,    61,    62,    63,    64,
      65,    66,    67,    68,    69,    70,    71,    72,    73,    74,
      75,    76,    77,    78,    79,    80,    81,    82,    83,    84,
      85,    86,    87,    88,    89,    90,    91,    92,    93,    94,
      95,    96,    97,    98,    99,   100,   101,   102,   103,   104,
     105,   106,   107,   108,   109,   110,   111,   112,   113,   114,
     115,   116,   117,   118,   119,   120,   121,   122,   123,   124,
     125,   126,   127,   128,   129,   130,   131,   132,   133,   134,
     135,   136,   137,   138,   139,   140,   141,   142,   143,   144,
     145,   146,   147,   148,   149,   150,   151,   152,   153,   154,
     155,   156,   157,   158,   159,   160,   161,   162,   163,   164,
     165,   166,   167,   168,   169,   170,   171,   172,   173,   174,
     175,   176,   177,   178,   179,   180,   181,   182,   183
};

#if YYDEBUG
/* YYPRHS[YYN] -- Index of the first RHS symbol of rule number YYN in
   YYRHS.  */
static const yytype_uint16 yyprhs[] =
{
       0,     0,     3,     5,     8,    10,    12,    15,    17,    19,
      21,    23,    25,    27,    29,    31,    33,    35,    37,    39,
      41,    43,    45,    47,    50,    54,    58,    64,    68,    71,
      74,    78,    81,    85,    88,    93,   100,   109,   120,   133,
     138,   145,   154,   165,   178,   193,   196,   200,   204,   207,
     212,   215,   220,   223,   228,   231,   236,   239,   243,   246,
     250,   252,   255,   259,   263,   269,   273,   279,   283,   289,
     293,   299,   303,   306,   310,   313,   318,   324,   325,   331,
     335,   339,   342,   348,   354,   360,   366,   372,   376,   379,
     383,   386,   390,   393,   397,   400,   404,   407,   410,   413,
     418,   424,   430,   436,   439,   443,   446,   452,   455,   461,
     464,   468,   471,   475,   478,   482,   488,   492,   495,   501,
     507,   512,   516,   519,   523,   526,   530,   533,   537,   541,
     544,   547,   551,   554,   557,   560,   563,   567,   571,   575,
     578,   582,   586,   590,   594,   597,   601,   604,   608,   612,
     616,   622,   626,   631,   635,   639,   642,   647,   652,   655,
     660,   663,   667,   670,   675,   679,   683,   687,   690,   694,
     697,   702,   707,   714,   719,   724,   729,   734,   740,   746,
     752,   757,   763,   767,   772,   778,   783,   789,   795,   800,
     806,   812,   815,   819,   824,   828,   832,   838,   842,   848,
     852,   855,   859,   864,   867,   870,   872,   874,   875,   877,
     879,   881,   883,   885,   888,   890,   892,   893,   895,   898,
     902,   904,   908,   910,   912,   914,   915,   917,   919,   923,
     925,   929,   932,   933,   935,   939,   941,   943,   944,   946,
     948,   950,   952,   954,   956,   958,   962,   966,   970,   974,
     978,   982,   984,   987,   988,   992,   996,  1000,  1004,  1006,
    1008,  1010,  1017,  1022,  1026,  1028,  1030,  1032,  1035,  1037,
    1039,  1041,  1043,  1045,  1047,  1049,  1051,  1053,  1055,  1057,
    1058,  1060,  1062,  1064,  1066,  1068,  1070,  1072,  1074,  1078,
    1082,  1085,  1088,  1090,  1092,  1095,  1097,  1101,  1105,  1109,
    1113,  1117,  1123,  1131,  1137,  1141,  1145,  1149,  1153,  1157,
    1161,  1167,  1173,  1179,  1185,  1186,  1188,  1190,  1192,  1194,
    1196,  1198,  1200,  1202,  1204,  1206,  1208,  1210,  1212,  1214,
    1216,  1218,  1220,  1222,  1225,  1229,  1233,  1238,  1242,  1247,
    1250,  1254,  1258,  1262,  1266,  1272,  1278,  1285,  1291,  1298,
    1303,  1309,  1315,  1321,  1327,  1331,  1337,  1339,  1341,  1343,
    1345
};

/* YYRHS -- A `-1'-separated list of the rules' RHS.  */
static const yytype_int16 yyrhs[] =
{
     193,     0,    -1,   194,    -1,   245,    22,    -1,    22,    -1,
     196,    -1,   194,   196,    -1,    23,    -1,    22,    -1,     1,
      -1,   197,    -1,   199,    -1,   202,    -1,   200,    -1,   203,
      -1,   204,    -1,   205,    -1,   206,    -1,   207,    -1,   208,
      -1,   209,    -1,   210,    -1,    13,    -1,    71,   195,    -1,
      71,   228,   195,    -1,    71,   174,   195,    -1,    71,   228,
     227,   174,   195,    -1,    43,   226,   195,    -1,    43,   195,
      -1,    51,   195,    -1,    51,   226,   195,    -1,    92,   195,
      -1,    92,   175,   195,    -1,   112,   195,    -1,   112,   227,
     228,   195,    -1,   112,   227,   228,   227,   228,   195,    -1,
     112,   227,   228,   227,   228,   227,   228,   195,    -1,   112,
     227,   228,   227,   228,   227,   228,   227,   228,   195,    -1,
     112,   227,   228,   227,   228,   227,   228,   227,   228,   227,
     228,   195,    -1,   112,   227,   240,   195,    -1,   112,   227,
     240,   227,   228,   195,    -1,   112,   227,   240,   227,   228,
     227,   228,   195,    -1,   112,   227,   240,   227,   228,   227,
     228,   227,   228,   195,    -1,   112,   227,   240,   227,   228,
     227,   228,   227,   228,   227,   228,   195,    -1,   112,   227,
     240,   227,   228,   227,   228,   227,   228,   227,   228,   227,
     228,   195,    -1,    29,   195,    -1,    54,   214,   195,    -1,
      55,   214,   195,    -1,    63,   195,    -1,    63,   227,   231,
     195,    -1,    62,   195,    -1,    62,   227,   231,   195,    -1,
      32,   195,    -1,    32,   227,   231,   195,    -1,    33,   195,
      -1,    33,   227,   231,   195,    -1,    90,   195,    -1,    90,
     226,   195,    -1,   124,   195,    -1,   124,   182,   195,    -1,
     198,    -1,    44,   195,    -1,    44,   228,   195,    -1,    44,
     219,   195,    -1,    72,   228,   227,   214,   195,    -1,    72,
     214,   195,    -1,    73,   228,   227,   214,   195,    -1,    73,
     214,   195,    -1,    74,   226,   227,   173,   195,    -1,    75,
     173,   195,    -1,    75,   228,   227,   173,   195,    -1,    76,
     228,   195,    -1,    76,   195,    -1,    77,   228,   195,    -1,
      77,   195,    -1,   133,    21,   226,   195,    -1,   133,    21,
     226,    24,   195,    -1,    -1,    60,   226,   201,   246,   195,
      -1,    60,   226,   195,    -1,    61,   223,   195,    -1,    61,
     195,    -1,    42,   224,   227,   226,   195,    -1,    53,   224,
     227,   226,   195,    -1,    41,   224,   227,   235,   195,    -1,
      40,   224,   227,   237,   195,    -1,    48,   178,   227,   223,
     195,    -1,    48,   223,   195,    -1,    48,   195,    -1,    81,
     223,   195,    -1,    81,   195,    -1,    82,   223,   195,    -1,
      82,   195,    -1,    83,   223,   195,    -1,    83,   195,    -1,
      84,   223,   195,    -1,    84,   195,    -1,   113,   195,    -1,
     114,   195,    -1,   114,   227,   231,   195,    -1,   114,   227,
     231,   223,   195,    -1,   115,   214,   227,   231,   195,    -1,
      49,   217,   223,   232,   195,    -1,    49,   195,    -1,    91,
     223,   195,    -1,    91,   195,    -1,    67,   217,   223,   232,
     195,    -1,    67,   195,    -1,    50,   217,   223,   232,   195,
      -1,    50,   195,    -1,   180,   221,   195,    -1,   180,   195,
      -1,   181,   221,   195,    -1,   181,   195,    -1,    39,   221,
     195,    -1,    39,   221,   227,   231,   195,    -1,    57,   221,
     195,    -1,    57,   195,    -1,    58,   221,    15,   233,   195,
      -1,    59,   221,   227,   168,   195,    -1,    59,   221,     1,
     195,    -1,    27,   182,   195,    -1,    27,   195,    -1,    28,
     182,   195,    -1,    28,   195,    -1,    25,   182,   195,    -1,
      25,   195,    -1,    26,   214,   195,    -1,    47,   178,   195,
      -1,    47,   195,    -1,    65,   195,    -1,    65,   228,   195,
      -1,   120,   195,    -1,    69,   195,    -1,    56,   195,    -1,
     123,   195,    -1,   123,   182,   195,    -1,    68,   211,   195,
      -1,    64,   231,   195,    -1,    66,   195,    -1,    66,   211,
     195,    -1,     7,   231,   195,    -1,    70,   213,   195,    -1,
      87,   211,   195,    -1,    94,   195,    -1,    97,   212,   195,
      -1,    96,   195,    -1,    98,   213,   195,    -1,    99,   213,
     195,    -1,    95,   214,   195,    -1,    95,   214,   227,   231,
     195,    -1,   100,   168,   195,    -1,   101,   168,   168,   195,
      -1,   102,   214,   195,    -1,   103,   214,   195,    -1,   106,
     195,    -1,   106,   227,   231,   195,    -1,   107,   227,   231,
     195,    -1,   108,   195,    -1,   108,   227,   231,   195,    -1,
     109,   195,    -1,   110,   243,   195,    -1,   110,   195,    -1,
     111,   243,   243,   195,    -1,   111,   243,   195,    -1,   116,
     212,   195,    -1,   118,   119,   195,    -1,   118,   195,    -1,
     125,   182,   195,    -1,   125,   195,    -1,   125,   126,   241,
     195,    -1,   125,   127,   222,   195,    -1,   125,   127,   222,
     129,   240,   195,    -1,   125,   128,   226,   195,    -1,   125,
     130,   226,   195,    -1,   125,   132,   226,   195,    -1,   125,
     131,   240,   195,    -1,    34,   214,   215,   225,   195,    -1,
      35,   214,   215,   225,   195,    -1,    88,   214,   215,   226,
     195,    -1,    88,   214,   215,     1,    -1,    36,   214,   215,
     224,   195,    -1,    36,   214,     1,    -1,    36,   214,   215,
       1,    -1,    89,   214,   215,   224,   195,    -1,    89,   214,
     215,     1,    -1,    37,   214,   215,   225,   195,    -1,    38,
     214,   215,   226,   195,    -1,    38,   214,   215,     1,    -1,
      30,   231,   231,   225,   195,    -1,    31,   231,   231,   226,
     195,    -1,   117,   195,    -1,   117,   215,   195,    -1,   104,
     214,   231,   195,    -1,   105,   231,   195,    -1,   121,   214,
     195,    -1,   121,   214,   227,   243,   195,    -1,   122,   214,
     195,    -1,   122,   214,   227,   243,   195,    -1,    78,   214,
     195,    -1,    79,   195,    -1,    80,   214,   195,    -1,    85,
     226,   235,   195,    -1,    86,   195,    -1,    93,   195,    -1,
     170,    -1,   170,    -1,    -1,   171,    -1,   169,    -1,     1,
      -1,   240,    -1,     1,    -1,   216,    14,    -1,    14,    -1,
     216,    -1,    -1,   176,    -1,   228,   176,    -1,   219,   140,
     220,    -1,   220,    -1,   218,    21,   243,    -1,   240,    -1,
       1,    -1,   240,    -1,    -1,   224,    -1,   226,    -1,   226,
     227,   226,    -1,     9,    -1,   228,   227,     9,    -1,   227,
     226,    -1,    -1,   229,    -1,   228,   227,   229,    -1,   173,
      -1,   140,    -1,    -1,    16,    -1,    17,    -1,    18,    -1,
      19,    -1,    20,    -1,   230,    -1,   243,    -1,   231,   184,
     231,    -1,   231,   185,   231,    -1,   231,   186,   231,    -1,
     231,   187,   231,    -1,   188,   231,   189,    -1,   188,   231,
       1,    -1,   239,    -1,    15,   233,    -1,    -1,   233,   177,
     233,    -1,   233,   177,     1,    -1,   134,   233,   135,    -1,
     134,   233,     1,    -1,   234,    -1,   218,    -1,   243,    -1,
     190,   174,   191,   134,   233,   135,    -1,   190,   174,   191,
     226,    -1,   235,   227,   236,    -1,   236,    -1,   243,    -1,
     168,    -1,   237,   238,    -1,   238,    -1,   243,    -1,   183,
      -1,   168,    -1,   243,    -1,   218,    -1,     4,    -1,    12,
      -1,    10,    -1,    11,    -1,   240,    -1,    -1,    12,    -1,
      10,    -1,    11,    -1,     3,    -1,     6,    -1,     4,    -1,
       5,    -1,   242,    -1,   244,   141,   245,    -1,   245,   141,
     245,    -1,   245,   141,    -1,   172,   247,    -1,   245,    -1,
     244,    -1,   136,   243,    -1,   243,    -1,   243,   140,   138,
      -1,   243,   140,   139,    -1,   243,   140,   146,    -1,   243,
     140,   243,    -1,   134,   243,   135,    -1,   134,   243,   140,
     138,   135,    -1,   134,   243,   140,   146,   135,   140,   139,
      -1,   134,   243,   135,   140,   139,    -1,   134,   156,   135,
      -1,   134,   157,   135,    -1,   134,   158,   135,    -1,   134,
     159,   135,    -1,   134,   160,   135,    -1,   134,   161,   135,
      -1,   134,   243,   135,   140,   137,    -1,   134,   243,   135,
     140,   158,    -1,   134,   243,   135,   140,   159,    -1,   134,
     243,   135,   140,   160,    -1,    -1,   137,    -1,   149,    -1,
     150,    -1,   151,    -1,   152,    -1,   153,    -1,   162,    -1,
     164,    -1,   154,    -1,   163,    -1,   165,    -1,   155,    -1,
     156,    -1,   157,    -1,   158,    -1,   159,    -1,   160,    -1,
     161,    -1,   144,   243,    -1,   243,   140,   249,    -1,   140,
     248,   166,    -1,   140,   248,   166,   166,    -1,   140,   167,
     248,    -1,   140,   167,   167,   248,    -1,   140,   248,    -1,
     149,   140,   248,    -1,   137,   140,   248,    -1,   151,   140,
     248,    -1,   243,   140,   147,    -1,   142,   243,   140,   248,
     143,    -1,   142,   140,   248,   166,   143,    -1,   142,   140,
     248,   166,   166,   143,    -1,   142,   140,   167,   248,   143,
      -1,   142,   140,   167,   167,   248,   143,    -1,   142,   140,
     248,   143,    -1,   142,   149,   140,   248,   143,    -1,   142,
     137,   140,   248,   143,    -1,   142,   151,   140,   248,   143,
      -1,   142,   243,   140,   147,   143,    -1,   142,   243,   143,
      -1,   142,   243,   143,   140,   139,    -1,   138,    -1,   139,
      -1,   249,    -1,   146,    -1,   145,    -1
};

/* YYRLINE[YYN] -- source line where rule number YYN was defined.  */
static const yytype_uint16 yyrline[] =
{
       0,   189,   189,   190,   191,   194,   195,   198,   199,   200,
     203,   204,   205,   206,   207,   208,   209,   210,   211,   212,
     213,   214,   215,   218,   220,   222,   224,   226,   228,   230,
     232,   234,   236,   238,   240,   242,   244,   246,   248,   250,
     252,   254,   256,   258,   260,   262,   264,   266,   268,   270,
     272,   274,   276,   278,   280,   282,   284,   286,   288,   293,
     297,   300,   302,   304,   307,   312,   317,   319,   321,   323,
     325,   327,   329,   331,   333,   335,   339,   346,   345,   348,
     350,   352,   356,   358,   360,   362,   364,   366,   368,   370,
     372,   374,   376,   378,   380,   382,   384,   386,   388,   390,
     392,   394,   398,   407,   410,   414,   417,   426,   429,   438,
     443,   445,   447,   449,   451,   453,   455,   457,   459,   461,
     463,   467,   469,   474,   481,   489,   496,   508,   512,   514,
     532,   534,   536,   538,   540,   542,   544,   548,   550,   552,
     554,   556,   558,   560,   562,   564,   566,   568,   570,   572,
     574,   576,   578,   580,   582,   584,   586,   588,   590,   592,
     594,   596,   598,   600,   602,   604,   606,   608,   610,   612,
     614,   616,   618,   620,   622,   624,   626,   630,   632,   634,
     636,   638,   640,   642,   644,   646,   648,   650,   652,   654,
     656,   658,   660,   662,   664,   666,   668,   670,   672,   676,
     678,   680,   684,   686,   690,   698,   701,   702,   705,   708,
     709,   712,   713,   716,   717,   720,   721,   724,   730,   738,
     739,   742,   746,   747,   750,   751,   754,   755,   758,   759,
     761,   765,   766,   769,   774,   779,   789,   790,   793,   794,
     795,   796,   797,   800,   802,   827,   828,   829,   830,   831,
     832,   833,   836,   837,   839,   844,   846,   848,   850,   854,
     860,   867,   880,   894,   895,   898,   899,   902,   903,   906,
     907,   908,   911,   912,   915,   916,   917,   918,   921,   922,
     925,   926,   927,   930,   931,   932,   933,   934,   937,   938,
     939,   942,   952,   953,   956,   963,   974,   985,   993,  1012,
    1018,  1026,  1034,  1036,  1038,  1039,  1040,  1041,  1042,  1043,
    1044,  1046,  1048,  1050,  1052,  1053,  1054,  1055,  1056,  1057,
    1058,  1059,  1060,  1061,  1062,  1063,  1064,  1065,  1066,  1067,
    1068,  1069,  1070,  1072,  1073,  1088,  1092,  1096,  1100,  1104,
    1108,  1112,  1116,  1120,  1132,  1147,  1151,  1155,  1159,  1163,
    1167,  1171,  1175,  1179,  1191,  1196,  1204,  1205,  1206,  1207,
    1211
};
#endif

#if YYDEBUG || YYERROR_VERBOSE || YYTOKEN_TABLE
/* YYTNAME[SYMBOL-NUM] -- String name of the symbol SYMBOL-NUM.
   First, the terminals, then, starting at YYNTOKENS, nonterminals.  */
static const char *const yytname[] =
{
  "$end", "error", "$undefined", "H_NUMBER", "D_NUMBER", "O_NUMBER",
  "B_NUMBER", "CONVERT_OP", "B_DATA", "H_RANGE_GUESS", "D_NUMBER_GUESS",
  "O_NUMBER_GUESS", "B_NUMBER_GUESS", "BAD_CMD", "MEM_OP", "IF",
  "MEM_COMP", "MEM_DISK8", "MEM_DISK9", "MEM_DISK10", "MEM_DISK11",
  "EQUALS", "TRAIL", "CMD_SEP", "LABEL_ASGN_COMMENT", "CMD_LOG",
  "CMD_LOGNAME", "CMD_SIDEFX", "CMD_DUMMY", "CMD_RETURN", "CMD_BLOCK_READ",
  "CMD_BLOCK_WRITE", "CMD_UP", "CMD_DOWN", "CMD_LOAD", "CMD_BASICLOAD",
  "CMD_SAVE", "CMD_VERIFY", "CMD_BVERIFY", "CMD_IGNORE", "CMD_HUNT",
  "CMD_FILL", "CMD_MOVE", "CMD_GOTO", "CMD_REGISTERS", "CMD_READSPACE",
  "CMD_WRITESPACE", "CMD_RADIX", "CMD_MEM_DISPLAY", "CMD_BREAK",
  "CMD_TRACE", "CMD_IO", "CMD_BRMON", "CMD_COMPARE", "CMD_DUMP",
  "CMD_UNDUMP", "CMD_EXIT", "CMD_DELETE", "CMD_CONDITION", "CMD_COMMAND",
  "CMD_ASSEMBLE", "CMD_DISASSEMBLE", "CMD_NEXT", "CMD_STEP", "CMD_PRINT",
  "CMD_DEVICE", "CMD_HELP", "CMD_WATCH", "CMD_DISK", "CMD_QUIT",
  "CMD_CHDIR", "CMD_BANK", "CMD_LOAD_LABELS", "CMD_SAVE_LABELS",
  "CMD_ADD_LABEL", "CMD_DEL_LABEL", "CMD_SHOW_LABELS", "CMD_CLEAR_LABELS",
  "CMD_RECORD", "CMD_MON_STOP", "CMD_PLAYBACK", "CMD_CHAR_DISPLAY",
  "CMD_SPRITE_DISPLAY", "CMD_TEXT_DISPLAY", "CMD_SCREENCODE_DISPLAY",
  "CMD_ENTER_DATA", "CMD_ENTER_BIN_DATA", "CMD_KEYBUF", "CMD_BLOAD",
  "CMD_BSAVE", "CMD_SCREEN", "CMD_UNTIL", "CMD_CPU", "CMD_YYDEBUG",
  "CMD_BACKTRACE", "CMD_SCREENSHOT", "CMD_PWD", "CMD_DIR", "CMD_MKDIR",
  "CMD_RMDIR", "CMD_RESOURCE_GET", "CMD_RESOURCE_SET",
  "CMD_LOAD_RESOURCES", "CMD_SAVE_RESOURCES", "CMD_ATTACH", "CMD_DETACH",
  "CMD_MON_RESET", "CMD_TAPECTRL", "CMD_TAPEOFFS", "CMD_CARTFREEZE",
  "CMD_UPDB", "CMD_JPDB", "CMD_CPUHISTORY", "CMD_MEMMAPZAP",
  "CMD_MEMMAPSHOW", "CMD_MEMMAPSAVE", "CMD_COMMENT", "CMD_LIST",
  "CMD_STOPWATCH", "RESET", "CMD_EXPORT", "CMD_AUTOSTART", "CMD_AUTOLOAD",
  "CMD_MAINCPU_TRACE", "CMD_WARP", "CMD_PROFILE", "FLAT", "GRAPH", "FUNC",
  "DEPTH", "DISASS", "PROFILE_CONTEXT", "CLEAR", "CMD_LABEL_ASGN",
  "L_PAREN", "R_PAREN", "ARG_IMMEDIATE", "REG_A", "REG_X", "REG_Y",
  "COMMA", "INST_SEP", "L_BRACKET", "R_BRACKET", "LESS_THAN", "REG_U",
  "REG_S", "REG_PC", "REG_PCR", "REG_B", "REG_C", "REG_D", "REG_E",
  "REG_H", "REG_L", "REG_AF", "REG_BC", "REG_DE", "REG_HL", "REG_IX",
  "REG_IY", "REG_SP", "REG_IXH", "REG_IXL", "REG_IYH", "REG_IYL", "PLUS",
  "MINUS", "STRING", "FILENAME", "R_O_L", "R_O_L_Q", "OPCODE", "LABEL",
  "BANKNAME", "CPUTYPE", "MON_REGISTER", "COND_OP", "RADIX_TYPE",
  "INPUT_SPEC", "CMD_CHECKPT_ON", "CMD_CHECKPT_OFF", "TOGGLE", "MASK",
  "'+'", "'-'", "'*'", "'/'", "'('", "')'", "'@'", "':'", "$accept",
  "top_level", "command_list", "end_cmd", "command", "machine_state_rules",
  "register_mod", "symbol_table_rules", "asm_rules", "@1", "memory_rules",
  "checkpoint_rules", "checkpoint_control_rules", "monitor_state_rules",
  "monitor_misc_rules", "disk_rules", "cmd_file_rules", "data_entry_rules",
  "monitor_debug_rules", "rest_of_line", "opt_rest_of_line",
  "rest_of_line_or_quoted", "filename", "device_num", "mem_op",
  "opt_mem_op", "register", "reg_list", "reg_asgn", "checkpt_num",
  "opt_context_num", "address_opt_range", "address_range", "opt_address",
  "address", "opt_sep", "memspace", "memloc", "memaddr", "expression",
  "opt_if_cond_expr", "cond_expr", "cond_operand", "data_list",
  "data_element", "hunt_list", "hunt_element", "value", "d_number",
  "opt_d_number", "guess_default", "number", "assembly_instr_list",
  "assembly_instruction", "post_assemble", "asm_operand_mode", "index_reg",
  "index_ureg", 0
};
#endif

# ifdef YYPRINT
/* YYTOKNUM[YYLEX-NUM] -- Internal token number corresponding to
   token YYLEX-NUM.  */
static const yytype_uint16 yytoknum[] =
{
       0,   256,   257,   258,   259,   260,   261,   262,   263,   264,
     265,   266,   267,   268,   269,   270,   271,   272,   273,   274,
     275,   276,   277,   278,   279,   280,   281,   282,   283,   284,
     285,   286,   287,   288,   289,   290,   291,   292,   293,   294,
     295,   296,   297,   298,   299,   300,   301,   302,   303,   304,
     305,   306,   307,   308,   309,   310,   311,   312,   313,   314,
     315,   316,   317,   318,   319,   320,   321,   322,   323,   324,
     325,   326,   327,   328,   329,   330,   331,   332,   333,   334,
     335,   336,   337,   338,   339,   340,   341,   342,   343,   344,
     345,   346,   347,   348,   349,   350,   351,   352,   353,   354,
     355,   356,   357,   358,   359,   360,   361,   362,   363,   364,
     365,   366,   367,   368,   369,   370,   371,   372,   373,   374,
     375,   376,   377,   378,   379,   380,   381,   382,   383,   384,
     385,   386,   387,   388,   389,   390,   391,   392,   393,   394,
     395,   396,   397,   398,   399,   400,   401,   402,   403,   404,
     405,   406,   407,   408,   409,   410,   411,   412,   413,   414,
     415,   416,   417,   418,   419,   420,   421,   422,   423,   424,
     425,   426,   427,   428,   429,   430,   431,   432,   433,   434,
     435,   436,   437,   438,    43,    45,    42,    47,    40,    41,
      64,    58
};
# endif

/* YYR1[YYN] -- Symbol number of symbol that rule YYN derives.  */
static const yytype_uint8 yyr1[] =
{
       0,   192,   193,   193,   193,   194,   194,   195,   195,   195,
     196,   196,   196,   196,   196,   196,   196,   196,   196,   196,
     196,   196,   196,   197,   197,   197,   197,   197,   197,   197,
     197,   197,   197,   197,   197,   197,   197,   197,   197,   197,
     197,   197,   197,   197,   197,   197,   197,   197,   197,   197,
     197,   197,   197,   197,   197,   197,   197,   197,   197,   197,
     197,   198,   198,   198,   199,   199,   199,   199,   199,   199,
     199,   199,   199,   199,   199,   199,   199,   201,   200,   200,
     200,   200,   202,   202,   202,   202,   202,   202,   202,   202,
     202,   202,   202,   202,   202,   202,   202,   202,   202,   202,
     202,   202,   203,   203,   203,   203,   203,   203,   203,   203,
     204,   204,   204,   204,   204,   204,   204,   204,   204,   204,
     204,   205,   205,   205,   205,   205,   205,   205,   205,   205,
     205,   205,   205,   205,   205,   205,   205,   206,   206,   206,
     206,   206,   206,   206,   206,   206,   206,   206,   206,   206,
     206,   206,   206,   206,   206,   206,   206,   206,   206,   206,
     206,   206,   206,   206,   206,   206,   206,   206,   206,   206,
     206,   206,   206,   206,   206,   206,   206,   207,   207,   207,
     207,   207,   207,   207,   207,   207,   207,   207,   207,   207,
     207,   207,   207,   207,   207,   207,   207,   207,   207,   208,
     208,   208,   209,   209,   210,   211,   212,   212,   213,   214,
     214,   215,   215,   216,   216,   217,   217,   218,   218,   219,
     219,   220,   221,   221,   222,   222,   223,   223,   224,   224,
     224,   225,   225,   226,   226,   226,   227,   227,   228,   228,
     228,   228,   228,   229,   230,   231,   231,   231,   231,   231,
     231,   231,   232,   232,   233,   233,   233,   233,   233,   234,
     234,   234,   234,   235,   235,   236,   236,   237,   237,   238,
     238,   238,   239,   239,   240,   240,   240,   240,   241,   241,
     242,   242,   242,   243,   243,   243,   243,   243,   244,   244,
     244,   245,   246,   246,   247,   247,   247,   247,   247,   247,
     247,   247,   247,   247,   247,   247,   247,   247,   247,   247,
     247,   247,   247,   247,   247,   247,   247,   247,   247,   247,
     247,   247,   247,   247,   247,   247,   247,   247,   247,   247,
     247,   247,   247,   247,   247,   247,   247,   247,   247,   247,
     247,   247,   247,   247,   247,   247,   247,   247,   247,   247,
     247,   247,   247,   247,   247,   247,   248,   248,   248,   248,
     249
};

/* YYR2[YYN] -- Number of symbols composing right hand side of rule YYN.  */
static const yytype_uint8 yyr2[] =
{
       0,     2,     1,     2,     1,     1,     2,     1,     1,     1,
       1,     1,     1,     1,     1,     1,     1,     1,     1,     1,
       1,     1,     1,     2,     3,     3,     5,     3,     2,     2,
       3,     2,     3,     2,     4,     6,     8,    10,    12,     4,
       6,     8,    10,    12,    14,     2,     3,     3,     2,     4,
       2,     4,     2,     4,     2,     4,     2,     3,     2,     3,
       1,     2,     3,     3,     5,     3,     5,     3,     5,     3,
       5,     3,     2,     3,     2,     4,     5,     0,     5,     3,
       3,     2,     5,     5,     5,     5,     5,     3,     2,     3,
       2,     3,     2,     3,     2,     3,     2,     2,     2,     4,
       5,     5,     5,     2,     3,     2,     5,     2,     5,     2,
       3,     2,     3,     2,     3,     5,     3,     2,     5,     5,
       4,     3,     2,     3,     2,     3,     2,     3,     3,     2,
       2,     3,     2,     2,     2,     2,     3,     3,     3,     2,
       3,     3,     3,     3,     2,     3,     2,     3,     3,     3,
       5,     3,     4,     3,     3,     2,     4,     4,     2,     4,
       2,     3,     2,     4,     3,     3,     3,     2,     3,     2,
       4,     4,     6,     4,     4,     4,     4,     5,     5,     5,
       4,     5,     3,     4,     5,     4,     5,     5,     4,     5,
       5,     2,     3,     4,     3,     3,     5,     3,     5,     3,
       2,     3,     4,     2,     2,     1,     1,     0,     1,     1,
       1,     1,     1,     2,     1,     1,     0,     1,     2,     3,
       1,     3,     1,     1,     1,     0,     1,     1,     3,     1,
       3,     2,     0,     1,     3,     1,     1,     0,     1,     1,
       1,     1,     1,     1,     1,     3,     3,     3,     3,     3,
       3,     1,     2,     0,     3,     3,     3,     3,     1,     1,
       1,     6,     4,     3,     1,     1,     1,     2,     1,     1,
       1,     1,     1,     1,     1,     1,     1,     1,     1,     0,
       1,     1,     1,     1,     1,     1,     1,     1,     3,     3,
       2,     2,     1,     1,     2,     1,     3,     3,     3,     3,
       3,     5,     7,     5,     3,     3,     3,     3,     3,     3,
       5,     5,     5,     5,     0,     1,     1,     1,     1,     1,
       1,     1,     1,     1,     1,     1,     1,     1,     1,     1,
       1,     1,     1,     2,     3,     3,     4,     3,     4,     2,
       3,     3,     3,     3,     5,     5,     6,     5,     6,     4,
       5,     5,     5,     5,     3,     5,     1,     1,     1,     1,
       1
};

/* YYDEFACT[STATE-NAME] -- Default rule to reduce with in state
   STATE-NUM when YYTABLE doesn't specify something else to do.  Zero
   means the default is an error.  */
static const yytype_uint16 yydefact[] =
{
       0,     0,    22,     4,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
       0,     0,     0,   207,     0,     0,     0,     0,     0,     0,
       0,     0,     0,   237,     0,     0,     0,     0,     0,     0,
       0,     0,   207,     0,     0,     0,     0,     0,     0,     0,
       0,     0,   314,     0,     0,     0,     2,     5,    10,    60,
      11,    13,    12,    14,    15,    16,    17,    18,    19,    20,
      21,     0,   283,   285,   286,   284,   281,   282,   280,   238,
     239,   240,   241,   242,   217,     0,   273,     0,     0,   251,
     287,   272,     9,     8,     7,     0,   126,   210,   209,     0,
       0,   122,     0,   124,    45,     0,     0,   236,    52,     0,
      54,     0,     0,     0,     0,     0,     0,   223,   274,   276,
     277,   275,     0,   222,   229,   235,   237,   237,   237,   233,
     243,   244,   237,   237,    28,     0,   237,    61,     0,     0,
     220,     0,     0,   129,   237,    88,     0,   226,   237,   214,
     103,   215,     0,   109,     0,    29,     0,   237,     0,     0,
     134,     9,   117,     0,     0,     0,     0,    81,     0,    50,
       0,    48,     0,     0,   130,     0,   205,   139,     0,   107,
       0,     0,   133,   208,     0,     0,    23,     0,     0,   237,
       0,   237,   237,     0,   237,    72,     0,    74,     0,     0,
     200,     0,    90,     0,    92,     0,    94,     0,    96,     0,
       0,   203,     0,     0,     0,    56,     0,   105,     0,     0,
      31,   204,   144,     0,   146,   206,     0,     0,     0,     0,
       0,     0,     0,     0,     0,   155,     0,     0,   158,     0,
     160,   162,     0,     0,    33,     0,    97,    98,     0,   237,
       0,     9,   191,     0,   211,     0,   167,   132,     0,     0,
       0,   135,     0,    58,   279,   225,     0,     0,     0,     0,
       0,   169,     0,     0,     0,   315,     0,     0,     0,   316,
     317,   318,   319,   320,   323,   326,   327,   328,   329,   330,
     331,   332,   321,   324,   322,   325,   295,   291,   111,     0,
     113,     0,     1,     6,     3,     0,   218,     0,     0,     0,
       0,   141,   125,   127,   121,   123,   237,     0,     0,     0,
     212,   237,   237,   182,     0,   237,     0,   114,     0,     0,
       0,     0,     0,     0,    27,     0,     0,     0,    63,    62,
     128,     0,    87,   213,   253,   253,    30,     0,    46,    47,
     116,     0,     0,     0,    79,     0,    80,     0,     0,   138,
     131,   140,   253,   137,   142,    25,    24,     0,    65,     0,
      67,     0,     0,    69,     0,    71,    73,   199,   201,    89,
      91,    93,    95,   266,     0,   264,   265,   143,     0,     0,
      57,   104,    32,   149,     0,   145,   147,   148,   151,     0,
     153,   154,     0,   194,     0,     0,     0,   161,   164,     0,
       0,     0,     0,     0,   165,   192,   166,   195,     0,   197,
       0,   136,    59,   278,     0,     0,   224,     0,     0,     0,
       0,   168,     0,     0,     0,     0,     0,     0,     0,     0,
     294,     0,   356,   357,   360,   359,     0,   339,   358,     0,
       0,     0,     0,     0,   333,     0,     0,     0,   110,   112,
     250,   249,   245,   246,   247,   248,     0,     0,     0,    53,
      55,     0,     0,   183,     0,     0,   188,     0,     0,   271,
     270,     0,   268,   269,   228,   230,   234,     0,     0,   221,
     219,     0,     0,     0,     0,     0,     0,     0,   259,     0,
     258,   260,   120,     0,   293,   292,     0,    51,    49,     0,
       0,     0,     0,     0,     0,   202,     0,   180,     0,   185,
       0,     0,   152,   193,   156,   157,   159,   163,    34,     0,
      39,     0,    99,     0,     0,     0,     0,   170,     0,   171,
     173,   174,   176,   175,     0,    75,   304,   305,   306,   307,
     308,   309,   300,     0,   341,     0,   337,   335,     0,     0,
       0,     0,     0,     0,   354,   340,   342,   296,   297,   298,
     343,   299,   334,   189,   231,   190,   177,   178,   181,   186,
     187,   115,    85,   267,    84,    82,    86,   252,   102,   108,
      83,     0,     0,     0,   118,   119,     0,   290,    78,   106,
      26,    64,    66,    68,    70,   263,   179,   184,   150,     0,
       0,   100,   101,   196,   198,     0,    76,     0,     0,     0,
     338,   336,     0,     0,     0,   349,     0,     0,     0,     0,
       0,     0,   257,   256,     0,   255,   254,   288,   289,    35,
       0,    40,     0,   172,   310,   303,   311,   312,   313,   301,
       0,   351,     0,   347,   345,     0,   350,   352,   353,   344,
     355,     0,   262,     0,     0,     0,   348,   346,     0,    36,
       0,    41,     0,   302,   261,     0,     0,    37,     0,    42,
       0,     0,     0,    38,    43,     0,     0,    44
};

/* YYDEFGOTO[NTERM-NUM].  */
static const yytype_int16 yydefgoto[] =
{
      -1,   105,   106,   146,   107,   108,   109,   110,   111,   405,
     112,   113,   114,   115,   116,   117,   118,   119,   120,   228,
     276,   234,   149,   303,   201,   202,   136,   189,   190,   172,
     475,   196,   197,   516,   198,   517,   137,   179,   180,   138,
     543,   549,   550,   434,   435,   531,   532,   139,   304,   474,
     140,   181,   554,   121,   556,   347,   497,   498
};

/* YYPACT[STATE-NUM] -- Index in YYTABLE of the portion describing
   STATE-NUM.  */
#define YYPACT_NINF -428
static const yytype_int16 yypact[] =
{
    1425,   348,  -428,  -428,     2,     3,    68,    84,   477,   348,
     348,   387,   387,     3,     3,     3,     3,     3,   325,  1151,
    1151,  1151,  1406,   299,    49,  1176,  1224,  1224,  1406,  1151,
       3,     3,   477,  1028,   325,   325,  1766,  1248,   387,   387,
     348,  1303,    98,  1224,   -84,   477,   -76,   399,   407,   407,
    1766,   420,  1303,  1303,     3,   477,     3,  1248,  1248,  1248,
    1248,  1766,   477,   -84,     3,     3,  1406,  1248,   186,   477,
     477,     3,   477,   -70,   -76,   -76,   -56,   -41,     3,     3,
       3,   348,   387,   -12,   387,   477,  1052,  1801,  1295,   477,
     387,     3,   -70,  1346,   410,   477,     3,     3,   107,   148,
     440,   124,  1791,  1028,  1028,   150,  1582,  -428,  -428,  -428,
    -428,  -428,  -428,  -428,  -428,  -428,  -428,  -428,  -428,  -428,
    -428,   129,  -428,  -428,  -428,  -428,  -428,  -428,  -428,  -428,
    -428,  -428,  -428,  -428,  -428,   348,  -428,   -21,   125,  -428,
    -428,  -428,  -428,  -428,  -428,   477,  -428,  -428,  -428,   477,
     477,  -428,   477,  -428,  -428,   962,   962,  -428,  -428,   348,
    -428,   348,   865,   865,   936,   865,   865,  -428,  -428,  -428,
    -428,  -428,   387,  -428,  -428,  -428,   -12,   -12,   -12,  -428,
    -428,  -428,   -12,   -12,  -428,   477,   -12,  -428,   135,   522,
    -428,   158,   477,  -428,   -12,  -428,   477,  -428,   559,  -428,
    -428,   151,  1151,  -428,  1151,  -428,   477,   -12,   477,   477,
    -428,   519,  -428,   477,   149,    14,   356,  -428,   477,  -428,
     348,  -428,   348,   125,  -428,   477,  -428,  -428,   477,  -428,
    1151,   477,  -428,  -428,   477,   477,  -428,   444,   477,   -12,
     477,   -12,   -12,   477,   -12,  -428,   477,  -428,   477,   477,
    -428,   477,  -428,   477,  -428,   477,  -428,   477,  -428,   477,
     838,  -428,   477,   865,   865,  -428,   477,  -428,   477,   477,
    -428,  -428,  -428,   387,  -428,  -428,   477,   477,   477,   477,
      20,   477,   477,   348,   125,  -428,   348,   348,  -428,   348,
    -428,  -428,   477,  1052,  -428,  1363,  -428,  -428,   348,   -12,
     477,   598,  -428,   477,  -428,   477,  -428,  -428,  1330,  1330,
     477,  -428,   477,  -428,   780,   780,  1766,  1766,   780,  1766,
     477,  -428,  1766,  1116,  1801,    55,    59,  1820,  1801,    61,
    -428,    66,  -428,  -428,  -428,  -428,  -428,  -428,  -428,  -428,
    -428,  -428,  -428,  -428,  -428,  -428,    71,  -428,  -428,   477,
    -428,   477,  -428,  -428,  -428,     7,  -428,   348,   348,   348,
     348,  -428,  -428,  -428,  -428,  -428,    95,  1096,   125,   125,
    -428,   584,   584,  1383,  1556,   584,  1199,  -428,   348,   801,
    1766,  1581,   838,  1766,  -428,  1801,  1801,   357,  -428,  -428,
    -428,  1151,  -428,  -428,   163,   163,  -428,  1766,  -428,  -428,
    -428,   476,   477,    21,  -428,    43,  -428,   125,   125,  -428,
    -428,  -428,   163,  -428,  -428,  -428,  -428,    56,  -428,     3,
    -428,     3,    45,  -428,    51,  -428,  -428,  -428,  -428,  -428,
    -428,  -428,  -428,  -428,   909,  -428,  -428,  -428,  1727,  1707,
    -428,  -428,  -428,  -428,   348,  -428,  -428,  -428,  -428,   477,
    -428,  -428,   125,  -428,   125,   125,   125,  -428,  -428,   477,
     995,   995,   886,   348,  -428,  -428,  -428,  -428,  1801,  -428,
    1801,  -428,  -428,  -428,   477,   482,  -428,   477,   477,   477,
     477,  -428,   607,    88,   104,   106,   109,   117,   126,   -65,
    -428,    75,  -428,  -428,  -428,  -428,   544,    67,  -428,   137,
     693,   143,   145,  -131,  -428,    75,    75,  1834,  -428,  -428,
    -428,  -428,   -64,   -64,  -428,  -428,   477,  1766,   477,  -428,
    -428,   477,   477,  -428,   477,   477,  -428,   477,   125,  -428,
    -428,   130,  -428,  -428,  -428,  -428,  -428,   909,   477,  -428,
    -428,   477,   476,   477,   477,   477,   476,    90,  -428,   115,
    -428,  -428,  -428,   477,   128,   147,   477,  -428,  -428,   477,
     477,   477,   477,   477,   477,  -428,   838,  -428,   477,  -428,
     477,   125,  -428,  -428,  -428,  -428,  -428,  -428,  -428,   696,
    -428,   696,  -428,   477,   125,   477,   477,  -428,   780,  -428,
    -428,  -428,  -428,  -428,   477,  -428,  -428,  -428,  -428,  -428,
    -428,  -428,   153,   -98,  -428,    75,  -428,   141,    75,   726,
    -132,    75,    75,   796,   155,  -428,  -428,  -428,  -428,  -428,
    -428,  -428,  -428,  -428,  -428,  -428,  -428,  -428,  -428,  -428,
    -428,  -428,  -428,  -428,  -428,  -428,  -428,   113,  -428,  -428,
    -428,    22,    74,   157,  -428,  -428,    43,    43,  -428,  -428,
    -428,  -428,  -428,  -428,  -428,  -428,  -428,  -428,  -428,   995,
     995,  -428,  -428,  -428,  -428,   477,  -428,    99,   161,   166,
    -428,  -428,   165,    75,   177,  -428,  -101,   180,   184,   188,
     189,   199,  -428,  -428,  1748,  -428,  -428,  -428,  -428,  -428,
     696,  -428,   696,  -428,  -428,  -428,  -428,  -428,  -428,  -428,
     204,  -428,   203,  -428,  -428,   207,  -428,  -428,  -428,  -428,
    -428,   476,  -428,   995,   995,   216,  -428,  -428,   -67,  -428,
     696,  -428,   696,  -428,  -428,   995,   995,  -428,   696,  -428,
     696,   477,   995,  -428,  -428,   696,   477,  -428
};

/* YYPGOTO[NTERM-NUM].  */
static const yytype_int16 yypgoto[] =
{
    -428,  -428,  -428,    -6,   263,  -428,  -428,  -428,  -428,  -428,
    -428,  -428,  -428,  -428,  -428,  -428,  -428,  -428,  -428,   -34,
     280,    50,   803,   481,  -428,   -13,   -16,  -428,    -7,   581,
    -428,    44,    38,  -298,   320,   419,   714,  -276,  -428,   641,
    -357,  -427,  -428,     0,  -183,  -428,  -147,  -428,    10,  -428,
    -428,   666,  -428,  -392,  -428,  -428,   174,  -120
};

/* YYTABLE[YYPACT[STATE-NUM]].  What to do in state STATE-NUM.  If
   positive, shift that token.  If negative, reduce the rule which
   number is the opposite.  If zero, do what YYDEFACT says.
   If YYTABLE_NINF, syntax error.  */
#define YYTABLE_NINF -238
static const yytype_int16 yytable[] =
{
     151,   153,   154,   142,   147,   158,   160,   188,   510,   613,
     231,   675,   614,   555,   204,   402,   184,   187,   193,   195,
     200,   203,   205,   682,   143,   144,   210,   212,   173,   262,
     230,   217,   219,   221,   676,   224,   227,   229,   544,   232,
     668,   236,   704,   173,   173,   173,   245,   247,   669,   250,
     142,   252,   254,   256,   258,   559,   261,   176,   182,   183,
     265,   267,   270,   271,   272,   705,   274,   207,   724,   142,
     602,   143,   144,   521,   522,   603,   285,   525,   288,   290,
     291,   218,   294,   296,   297,   142,   226,   302,   306,   307,
     143,   144,   311,   313,   321,   233,  -232,   348,   350,   142,
     275,   253,   255,   257,   259,   536,   143,   144,   142,   536,
     643,   268,   279,   173,   173,   637,   142,  -232,  -232,   641,
     143,   144,   359,   360,   277,   278,   142,   280,   157,   143,
     144,   142,   361,   122,   123,   124,   125,   143,   144,   362,
     126,   127,   128,   363,   364,   322,   365,   143,   144,   142,
     352,   354,   143,   144,   157,   356,   386,   683,   685,   142,
     122,   123,   124,   125,   401,   393,   377,   126,   127,   128,
     143,   144,   148,   129,   130,   131,   132,   133,   542,   384,
     143,   144,  -237,   388,   145,   389,   390,   142,   449,   553,
     392,   357,   358,   359,   360,   491,   511,   492,   493,   643,
     396,   505,   398,   399,   494,   495,   506,   400,   143,   144,
     404,   507,   406,   492,   493,   102,   686,   409,   563,   410,
     494,   495,   411,   596,   564,   413,   496,   192,   414,   415,
     560,   416,   418,   607,   420,   157,   694,   423,   695,   597,
     425,   598,   426,   427,   599,   428,   394,   429,   395,   430,
     150,   431,   600,   432,   687,   688,   437,   696,   697,   698,
     440,   601,   441,   442,   642,   684,   152,   443,   226,   646,
     445,   446,   447,   448,   412,   450,   451,   608,   453,   357,
     358,   359,   360,   611,   718,   612,   457,   458,   647,   310,
     643,   546,   643,   667,   464,   681,   699,   465,   529,   466,
     142,   700,   467,   469,   471,   461,   472,   671,   701,   357,
     358,   359,   360,   530,   481,   129,   130,   131,   132,   133,
     703,   143,   144,   706,   473,   476,   167,   707,   479,   168,
     312,   708,   709,   134,   356,   169,   170,   171,   710,   177,
     177,   177,   185,   508,   715,   509,   716,   547,   206,   177,
     717,   122,   123,   124,   125,   723,   216,   142,   126,   127,
     128,   269,   519,   520,   129,   130,   131,   132,   133,   353,
     242,   188,   300,   129,   130,   131,   132,   133,   143,   144,
     540,   260,   537,   655,   633,   548,   266,   622,   142,     0,
    -237,  -237,  -237,  -237,     0,     0,   552,  -237,  -237,  -237,
     142,   557,   558,  -237,  -237,  -237,  -237,  -237,   147,   143,
     144,   142,   524,     0,     0,   129,   130,   131,   132,   133,
       0,   143,   144,   129,   130,   131,   132,   133,   565,     0,
     159,   161,   143,   144,     0,   541,   129,   130,   131,   132,
     133,   142,     0,   572,     0,   142,   573,     0,   574,   575,
     576,     0,     0,   577,   578,   580,   582,   220,   222,     0,
       0,     0,   143,   144,     0,     0,   143,   144,   587,   589,
       0,   590,   591,   592,   593,   134,   595,   570,   142,   122,
     123,   124,   125,   142,     0,     0,   126,   127,   128,     0,
       0,     0,   129,   130,   131,   132,   133,     0,     0,   143,
     144,   286,   287,   289,   143,   144,   583,   295,     0,   298,
     623,     0,   625,     0,     0,   626,   627,     0,   628,   629,
    -223,   630,   631,   142,   134,   632,   548,   157,   -77,   305,
     548,   634,   635,   134,     0,   636,   135,   638,   639,   640,
       0,  -223,  -223,   644,   143,   144,     0,   645,     0,     0,
     648,     0,     0,   649,   650,   651,   652,   653,   654,     0,
    -227,     0,   656,  -237,   657,   658,   314,   315,   316,     0,
     317,   318,   319,   235,  -227,  -237,   148,   661,   662,   663,
     664,  -227,  -227,     0,   157,  -232,     0,     0,   666,     0,
       0,   378,     0,   243,     0,   379,   380,   381,   665,  -212,
       0,   382,   383,     0,     0,   385,  -232,  -232,   142,     0,
     546,   588,     0,   391,   213,   214,   215,   380,  -237,     0,
    -212,  -212,   320,     0,     0,     0,   397,   548,     0,   143,
     144,   594,     0,     0,   403,     0,   477,   478,     0,   480,
       0,     0,   482,   371,   372,   374,   375,   376,     0,     0,
     155,   156,   134,   689,   691,     0,   417,     0,   419,   693,
     421,   422,   387,   424,     0,   604,   547,   141,     0,     0,
     606,     0,     0,     0,   610,   141,   141,     0,     0,   615,
     616,   223,   492,   493,   349,   351,     0,   518,     0,   494,
     495,     0,   444,     0,   177,   548,   527,     0,     0,   157,
     534,     0,     0,   538,     0,     0,   141,   719,   721,     0,
       0,   605,   129,   130,   131,   132,   133,   545,   463,   727,
     729,     0,   284,     0,   157,   733,   734,   468,   470,     0,
     737,     0,     0,   178,   178,   178,   186,   191,     0,   178,
       0,     0,   186,   178,   438,   439,     0,   141,     0,     0,
     186,   178,   292,   293,     0,   225,     0,     0,   568,   177,
       0,   237,   239,   241,   186,   244,   246,   248,   346,     0,
       0,   178,   178,   178,   178,   186,   355,     0,     0,   670,
     186,   178,   672,   674,   168,   677,   678,   680,     0,     0,
     169,   170,   171,     0,     0,     0,   366,   367,     0,     0,
     368,   141,   369,     0,   122,   123,   124,   125,     0,     0,
       0,   126,   127,   128,     0,     0,   162,   163,   164,   165,
     166,   141,   141,     0,     0,   141,     0,   141,     0,     0,
       0,   492,   493,   208,   209,     0,     0,   624,   494,   495,
       0,   122,   123,   124,   125,     0,     0,   702,   126,   127,
     128,   238,   240,   566,     0,     0,     0,   249,     0,   251,
     609,   407,     0,   408,   492,   493,   370,   263,   264,   168,
       0,   494,   495,     0,   273,   169,   170,   171,     0,   579,
     581,   281,   282,   283,     0,     0,   141,   142,   141,   122,
     123,   124,   125,   673,   299,   174,   126,   127,   128,   308,
     309,     0,   129,   130,   131,   132,   133,     0,   143,   144,
     142,     0,  -237,  -237,  -237,  -237,   178,     0,   178,  -237,
    -237,  -237,     0,     0,   452,     0,   436,   454,   455,     0,
     456,   143,   144,     0,   492,   493,     0,   373,     0,   462,
     168,   494,   495,   679,   178,     0,   169,   170,   171,   141,
       0,     0,   141,   141,     0,   141,   566,     0,     0,   459,
       0,     0,     0,     0,   141,   122,   123,   124,   125,   529,
       0,     0,   126,   127,   128,     0,     0,     0,   129,   130,
     131,   132,   133,     0,   530,     0,     0,     0,     0,   489,
     490,     0,     0,   503,   504,     0,   142,     0,   512,   513,
     514,   515,     0,     0,   712,     0,   433,     0,     0,   460,
       0,  -237,  -237,  -237,  -237,  -237,     0,   143,   144,   528,
       0,     0,     0,   141,   141,   141,   141,     0,     0,   211,
     186,   186,   168,   186,     0,     0,   186,     0,   169,   170,
     171,     0,     0,     0,   141,   533,     0,     0,   436,   157,
     143,   144,   539,   142,     0,   122,   123,   124,   125,   175,
       0,     0,   126,   127,   128,     0,     0,   551,     0,     0,
     357,   358,   359,   360,   143,   144,     0,  -237,   690,   692,
       0,   186,     0,     0,     0,   571,     0,     0,   178,     0,
     186,     0,     0,     0,   186,     0,     0,   186,     0,   122,
     123,   124,   125,     0,   584,   178,   126,   127,   128,     0,
     141,   186,   129,   130,   131,   132,   133,     0,     0,   122,
     123,   124,   125,     0,     0,     0,   126,   127,   128,   141,
       0,     0,   720,   722,   585,   157,   586,     0,   134,     0,
       0,     0,     0,     0,   728,   730,   357,   358,   359,   360,
     135,   735,   186,   178,   122,   123,   124,   125,     0,     0,
     174,   126,   127,   128,     0,     0,     0,   129,   130,   131,
     132,   133,     0,   621,     0,     0,   178,   142,     0,   122,
     123,   124,   125,     0,     0,   174,   126,   127,   128,     0,
       0,     0,   129,   130,   131,   132,   133,   533,   143,   144,
     526,     0,   122,   123,   124,   125,     0,     0,   551,   126,
     127,   128,   551,     0,     0,   129,   130,   131,   132,   133,
       0,     0,   561,     0,   562,   142,     0,  -216,  -216,  -216,
    -216,   186,   436,  -216,  -216,  -216,  -216,     0,   199,     0,
    -216,  -216,  -216,  -216,  -216,     0,   143,   144,     0,   142,
       0,   122,   123,   124,   125,     0,     0,   174,   126,   127,
     128,     0,     0,     0,   129,   130,   131,   132,   133,   175,
     143,   144,   483,   484,   485,   486,   487,   488,     0,     0,
     357,   358,   359,   360,     0,     0,     0,     0,     0,     0,
       0,     0,     0,   659,     0,   660,   142,     0,     0,  -237,
       0,     0,     0,     0,   142,  -237,  -237,  -237,     0,   551,
       0,  -237,  -237,  -237,  -237,  -237,     0,   143,   144,   129,
     130,   131,   132,   133,   175,   143,   144,     0,     0,     0,
       0,   142,     0,  -237,  -237,  -237,  -237,     0,     0,     0,
    -237,  -237,  -237,     0,     0,     0,     0,   301,     0,   175,
     168,     0,   143,   144,   194,     0,   169,   170,   171,     0,
       0,     0,     0,     0,     0,     0,     0,   168,   143,   144,
       0,     0,   175,   169,   170,   171,     0,   551,     0,   129,
     130,   131,   132,   133,  -212,     0,  -212,  -212,  -212,  -212,
       0,     0,  -212,  -212,  -212,  -212,     0,  -216,   186,  -212,
    -212,  -212,  -212,  -212,   713,     0,   714,   142,     0,   122,
     123,   124,   125,     0,     0,     0,   126,   127,   128,     0,
       0,   175,   129,   130,   131,   132,   133,     0,   143,   144,
       0,     0,     1,     0,   725,   157,   726,     0,     2,     0,
       0,     0,   731,     0,   732,     0,     0,     3,     0,   736,
       4,     5,     6,     7,     8,     9,    10,    11,    12,    13,
      14,    15,    16,    17,    18,    19,    20,    21,    22,    23,
     157,     0,    24,    25,    26,    27,    28,     0,    29,    30,
      31,    32,    33,    34,    35,    36,    37,    38,    39,    40,
      41,    42,    43,    44,    45,    46,    47,    48,    49,    50,
      51,    52,    53,    54,    55,    56,    57,    58,    59,    60,
      61,    62,    63,    64,    65,    66,    67,    68,    69,    70,
      71,    72,    73,    74,    75,    76,    77,    78,    79,    80,
      81,    82,    83,    84,    85,    86,    87,    88,    89,    90,
      91,    92,    93,    94,     0,    95,    96,    97,    98,    99,
     100,     0,     0,     0,     0,     0,  -212,   523,   101,   122,
     123,   124,   125,     0,     0,   174,   126,   127,   128,     0,
       0,     0,   129,   130,   131,   132,   133,     0,     0,   175,
       0,     0,     0,     0,   122,   123,   124,   125,     0,     1,
     535,   126,   127,   128,     0,     2,     0,   102,     0,     0,
       0,     0,     0,     0,     0,   103,   104,     4,     5,     6,
       7,     8,     9,    10,    11,    12,    13,    14,    15,    16,
      17,    18,    19,    20,    21,    22,    23,     0,     0,    24,
      25,    26,    27,    28,     0,    29,    30,    31,    32,    33,
      34,    35,    36,    37,    38,    39,    40,    41,    42,    43,
      44,    45,    46,    47,    48,    49,    50,    51,    52,    53,
      54,    55,    56,    57,    58,    59,    60,    61,    62,    63,
      64,    65,    66,    67,    68,    69,    70,    71,    72,    73,
      74,    75,    76,    77,    78,    79,    80,    81,    82,    83,
      84,    85,    86,    87,    88,    89,    90,    91,    92,    93,
      94,     0,    95,    96,    97,    98,    99,   100,   569,     0,
     122,   123,   124,   125,     0,   101,   174,   126,   127,   128,
       0,     0,     0,   129,   130,   131,   132,   133,   567,   175,
     122,   123,   124,   125,     0,     0,     0,   126,   127,   128,
       0,     0,     0,   129,   130,   131,   132,   133,     0,     0,
       0,   122,   123,   124,   125,     0,     0,     0,   126,   127,
     128,     0,   103,   104,   129,   130,   131,   132,   133,   122,
     123,   124,   125,     0,     0,     0,   126,   127,   128,     0,
       0,     0,   129,   130,   131,   132,   133,     0,     0,     0,
       0,     0,     0,     0,   122,   123,   124,   125,     0,     0,
       0,   126,   127,   128,   122,   123,   124,   125,     0,     0,
       0,   126,   127,   128,     0,     0,     0,     0,     0,     0,
       0,     0,     0,   122,   123,   124,   125,     0,     0,     0,
     126,   127,   128,     0,     0,     0,     0,   122,   123,   124,
     125,     0,     0,     0,   126,   127,   128,     0,     0,     0,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
     175,     0,   711,     0,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
     175,     0,     0,     0,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
       0,   175,     0,     0,     0,   323,     0,   324,   325,     0,
       0,   326,     0,   327,     0,   328,     0,     0,     0,   175,
     329,   330,   331,   332,   333,   334,   335,   336,   337,   338,
     339,   340,   341,   342,   343,   344,   345,   499,     0,     0,
     500,     0,     0,     0,     0,     0,     0,     0,     0,   501,
       0,   502,   617,   618,     0,     0,     0,     0,     0,   494,
     619,   620
};

static const yytype_int16 yycheck[] =
{
       6,     7,     8,     1,     1,    11,    12,    23,     1,   140,
      44,   143,   143,   405,    27,     1,    22,    23,    24,    25,
      26,    27,    28,     1,    22,    23,    32,    33,    18,    63,
      43,    37,    38,    39,   166,    41,    42,    43,   395,    45,
     138,    47,   143,    33,    34,    35,    52,    53,   146,    55,
       1,    57,    58,    59,    60,   412,    62,    19,    20,    21,
      66,    67,    68,    69,    70,   166,    72,    29,   135,     1,
     135,    22,    23,   371,   372,   140,    82,   375,    84,    85,
      86,    37,    88,    89,    90,     1,   170,    93,    94,    95,
      22,    23,    98,    99,   100,   171,     1,   103,   104,     1,
     170,    57,    58,    59,    60,   381,    22,    23,     1,   385,
     177,    67,   168,   103,   104,   542,     1,    22,    23,   546,
      22,    23,   186,   187,    74,    75,     1,   168,   140,    22,
      23,     1,   138,     3,     4,     5,     6,    22,    23,   145,
      10,    11,    12,   149,   150,    21,   152,    22,    23,     1,
       0,    22,    22,    23,   140,   176,    21,   135,     1,     1,
       3,     4,     5,     6,    15,    14,   172,    10,    11,    12,
      22,    23,   169,    16,    17,    18,    19,    20,    15,   185,
      22,    23,   168,   189,   182,   191,   192,     1,   168,   168,
     196,   184,   185,   186,   187,   140,   189,   138,   139,   177,
     206,   140,   208,   209,   145,   146,   140,   213,    22,    23,
     216,   140,   218,   138,   139,   172,   643,   223,   173,   225,
     145,   146,   228,   135,   173,   231,   167,   178,   234,   235,
     174,   237,   238,   166,   240,   140,   137,   243,   139,   135,
     246,   135,   248,   249,   135,   251,   202,   253,   204,   255,
     182,   257,   135,   259,   646,   647,   262,   158,   159,   160,
     266,   135,   268,   269,   174,   191,   182,   273,   170,   141,
     276,   277,   278,   279,   230,   281,   282,   140,   284,   184,
     185,   186,   187,   140,   711,   140,   292,   293,   141,   182,
     177,   134,   177,   140,   300,   140,   135,   303,   168,   305,
       1,   135,   308,   309,   310,   295,   312,   166,   143,   184,
     185,   186,   187,   183,   320,    16,    17,    18,    19,    20,
     143,    22,    23,   143,   314,   315,     1,   143,   318,     4,
     182,   143,   143,   176,   176,    10,    11,    12,   139,    19,
      20,    21,    22,   349,   140,   351,   143,   190,    28,    29,
     143,     3,     4,     5,     6,   139,    36,     1,    10,    11,
      12,   175,   368,   369,    16,    17,    18,    19,    20,   106,
      50,   387,    92,    16,    17,    18,    19,    20,    22,    23,
     387,    61,   382,   566,   531,   401,    66,   507,     1,    -1,
       3,     4,     5,     6,    -1,    -1,   402,    10,    11,    12,
       1,   407,   408,    16,    17,    18,    19,    20,     1,    22,
      23,     1,   374,    -1,    -1,    16,    17,    18,    19,    20,
      -1,    22,    23,    16,    17,    18,    19,    20,   434,    -1,
      11,    12,    22,    23,    -1,   391,    16,    17,    18,    19,
      20,     1,    -1,   449,    -1,     1,   452,    -1,   454,   455,
     456,    -1,    -1,   459,   460,   461,   462,    38,    39,    -1,
      -1,    -1,    22,    23,    -1,    -1,    22,    23,   474,   475,
      -1,   477,   478,   479,   480,   176,   482,   439,     1,     3,
       4,     5,     6,     1,    -1,    -1,    10,    11,    12,    -1,
      -1,    -1,    16,    17,    18,    19,    20,    -1,    -1,    22,
      23,    82,    83,    84,    22,    23,   462,    88,    -1,    90,
     516,    -1,   518,    -1,    -1,   521,   522,    -1,   524,   525,
       1,   527,   528,     1,   176,   531,   542,   140,   172,   119,
     546,   537,   538,   176,    -1,   541,   188,   543,   544,   545,
      -1,    22,    23,   549,    22,    23,    -1,   553,    -1,    -1,
     556,    -1,    -1,   559,   560,   561,   562,   563,   564,    -1,
       1,    -1,   568,   176,   570,   571,   126,   127,   128,    -1,
     130,   131,   132,   174,    15,   188,   169,   583,   584,   585,
     586,    22,    23,    -1,   140,     1,    -1,    -1,   594,    -1,
      -1,   172,    -1,   173,    -1,   176,   177,   178,   588,     1,
      -1,   182,   183,    -1,    -1,   186,    22,    23,     1,    -1,
     134,   129,    -1,   194,    33,    34,    35,   198,   174,    -1,
      22,    23,   182,    -1,    -1,    -1,   207,   643,    -1,    22,
      23,    24,    -1,    -1,   215,    -1,   316,   317,    -1,   319,
      -1,    -1,   322,   162,   163,   164,   165,   166,    -1,    -1,
       9,    10,   176,   659,   660,    -1,   237,    -1,   239,   665,
     241,   242,   140,   244,    -1,   491,   190,     1,    -1,    -1,
     496,    -1,    -1,    -1,   500,     9,    10,    -1,    -1,   505,
     506,    40,   138,   139,   103,   104,    -1,   367,    -1,   145,
     146,    -1,   273,    -1,   374,   711,   376,    -1,    -1,   140,
     380,    -1,    -1,   383,    -1,    -1,    40,   713,   714,    -1,
      -1,   167,    16,    17,    18,    19,    20,   397,   299,   725,
     726,    -1,    81,    -1,   140,   731,   732,   308,   309,    -1,
     736,    -1,    -1,    19,    20,    21,    22,    23,    -1,    25,
      -1,    -1,    28,    29,   263,   264,    -1,    81,    -1,    -1,
      36,    37,    86,    87,    -1,    41,    -1,    -1,   438,   439,
      -1,    47,    48,    49,    50,    51,    52,    53,   102,    -1,
      -1,    57,    58,    59,    60,    61,   135,    -1,    -1,   605,
      66,    67,   608,   609,     4,   611,   612,   613,    -1,    -1,
      10,    11,    12,    -1,    -1,    -1,   155,   156,    -1,    -1,
     159,   135,   161,    -1,     3,     4,     5,     6,    -1,    -1,
      -1,    10,    11,    12,    -1,    -1,    13,    14,    15,    16,
      17,   155,   156,    -1,    -1,   159,    -1,   161,    -1,    -1,
      -1,   138,   139,    30,    31,    -1,    -1,   517,   145,   146,
      -1,     3,     4,     5,     6,    -1,    -1,   673,    10,    11,
      12,    48,    49,   434,    -1,    -1,    -1,    54,    -1,    56,
     167,   220,    -1,   222,   138,   139,     1,    64,    65,     4,
      -1,   145,   146,    -1,    71,    10,    11,    12,    -1,   460,
     461,    78,    79,    80,    -1,    -1,   220,     1,   222,     3,
       4,     5,     6,   167,    91,     9,    10,    11,    12,    96,
      97,    -1,    16,    17,    18,    19,    20,    -1,    22,    23,
       1,    -1,     3,     4,     5,     6,   202,    -1,   204,    10,
      11,    12,    -1,    -1,   283,    -1,   260,   286,   287,    -1,
     289,    22,    23,    -1,   138,   139,    -1,     1,    -1,   298,
       4,   145,   146,   147,   230,    -1,    10,    11,    12,   283,
      -1,    -1,   286,   287,    -1,   289,   537,    -1,    -1,   293,
      -1,    -1,    -1,    -1,   298,     3,     4,     5,     6,   168,
      -1,    -1,    10,    11,    12,    -1,    -1,    -1,    16,    17,
      18,    19,    20,    -1,   183,    -1,    -1,    -1,    -1,   323,
     324,    -1,    -1,   327,   328,    -1,     1,    -1,   357,   358,
     359,   360,    -1,    -1,   684,    -1,   168,    -1,    -1,   295,
      -1,    16,    17,    18,    19,    20,    -1,    22,    23,   378,
      -1,    -1,    -1,   357,   358,   359,   360,    -1,    -1,     1,
     316,   317,     4,   319,    -1,    -1,   322,    -1,    10,    11,
      12,    -1,    -1,    -1,   378,   379,    -1,    -1,   382,   140,
      22,    23,   386,     1,    -1,     3,     4,     5,     6,   173,
      -1,    -1,    10,    11,    12,    -1,    -1,   401,    -1,    -1,
     184,   185,   186,   187,    22,    23,    -1,   168,   659,   660,
      -1,   367,    -1,    -1,    -1,   444,    -1,    -1,   374,    -1,
     376,    -1,    -1,    -1,   380,    -1,    -1,   383,    -1,     3,
       4,     5,     6,    -1,   463,   391,    10,    11,    12,    -1,
     444,   397,    16,    17,    18,    19,    20,    -1,    -1,     3,
       4,     5,     6,    -1,    -1,    -1,    10,    11,    12,   463,
      -1,    -1,   713,   714,   468,   140,   470,    -1,   176,    -1,
      -1,    -1,    -1,    -1,   725,   726,   184,   185,   186,   187,
     188,   732,   438,   439,     3,     4,     5,     6,    -1,    -1,
       9,    10,    11,    12,    -1,    -1,    -1,    16,    17,    18,
      19,    20,    -1,   507,    -1,    -1,   462,     1,    -1,     3,
       4,     5,     6,    -1,    -1,     9,    10,    11,    12,    -1,
      -1,    -1,    16,    17,    18,    19,    20,   531,    22,    23,
       1,    -1,     3,     4,     5,     6,    -1,    -1,   542,    10,
      11,    12,   546,    -1,    -1,    16,    17,    18,    19,    20,
      -1,    -1,   419,    -1,   421,     1,    -1,     3,     4,     5,
       6,   517,   566,     9,    10,    11,    12,    -1,    14,    -1,
      16,    17,    18,    19,    20,    -1,    22,    23,    -1,     1,
      -1,     3,     4,     5,     6,    -1,    -1,     9,    10,    11,
      12,    -1,    -1,    -1,    16,    17,    18,    19,    20,   173,
      22,    23,   156,   157,   158,   159,   160,   161,    -1,    -1,
     184,   185,   186,   187,    -1,    -1,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,   579,    -1,   581,     1,    -1,    -1,     4,
      -1,    -1,    -1,    -1,     1,    10,    11,    12,    -1,   643,
      -1,    16,    17,    18,    19,    20,    -1,    22,    23,    16,
      17,    18,    19,    20,   173,    22,    23,    -1,    -1,    -1,
      -1,     1,    -1,     3,     4,     5,     6,    -1,    -1,    -1,
      10,    11,    12,    -1,    -1,    -1,    -1,     1,    -1,   173,
       4,    -1,    22,    23,   178,    -1,    10,    11,    12,    -1,
      -1,    -1,    -1,    -1,    -1,    -1,    -1,     4,    22,    23,
      -1,    -1,   173,    10,    11,    12,    -1,   711,    -1,    16,
      17,    18,    19,    20,     1,    -1,     3,     4,     5,     6,
      -1,    -1,     9,    10,    11,    12,    -1,   173,   684,    16,
      17,    18,    19,    20,   690,    -1,   692,     1,    -1,     3,
       4,     5,     6,    -1,    -1,    -1,    10,    11,    12,    -1,
      -1,   173,    16,    17,    18,    19,    20,    -1,    22,    23,
      -1,    -1,     7,    -1,   720,   140,   722,    -1,    13,    -1,
      -1,    -1,   728,    -1,   730,    -1,    -1,    22,    -1,   735,
      25,    26,    27,    28,    29,    30,    31,    32,    33,    34,
      35,    36,    37,    38,    39,    40,    41,    42,    43,    44,
     140,    -1,    47,    48,    49,    50,    51,    -1,    53,    54,
      55,    56,    57,    58,    59,    60,    61,    62,    63,    64,
      65,    66,    67,    68,    69,    70,    71,    72,    73,    74,
      75,    76,    77,    78,    79,    80,    81,    82,    83,    84,
      85,    86,    87,    88,    89,    90,    91,    92,    93,    94,
      95,    96,    97,    98,    99,   100,   101,   102,   103,   104,
     105,   106,   107,   108,   109,   110,   111,   112,   113,   114,
     115,   116,   117,   118,    -1,   120,   121,   122,   123,   124,
     125,    -1,    -1,    -1,    -1,    -1,   173,     1,   133,     3,
       4,     5,     6,    -1,    -1,     9,    10,    11,    12,    -1,
      -1,    -1,    16,    17,    18,    19,    20,    -1,    -1,   173,
      -1,    -1,    -1,    -1,     3,     4,     5,     6,    -1,     7,
       9,    10,    11,    12,    -1,    13,    -1,   172,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,   180,   181,    25,    26,    27,
      28,    29,    30,    31,    32,    33,    34,    35,    36,    37,
      38,    39,    40,    41,    42,    43,    44,    -1,    -1,    47,
      48,    49,    50,    51,    -1,    53,    54,    55,    56,    57,
      58,    59,    60,    61,    62,    63,    64,    65,    66,    67,
      68,    69,    70,    71,    72,    73,    74,    75,    76,    77,
      78,    79,    80,    81,    82,    83,    84,    85,    86,    87,
      88,    89,    90,    91,    92,    93,    94,    95,    96,    97,
      98,    99,   100,   101,   102,   103,   104,   105,   106,   107,
     108,   109,   110,   111,   112,   113,   114,   115,   116,   117,
     118,    -1,   120,   121,   122,   123,   124,   125,     1,    -1,
       3,     4,     5,     6,    -1,   133,     9,    10,    11,    12,
      -1,    -1,    -1,    16,    17,    18,    19,    20,     1,   173,
       3,     4,     5,     6,    -1,    -1,    -1,    10,    11,    12,
      -1,    -1,    -1,    16,    17,    18,    19,    20,    -1,    -1,
      -1,     3,     4,     5,     6,    -1,    -1,    -1,    10,    11,
      12,    -1,   180,   181,    16,    17,    18,    19,    20,     3,
       4,     5,     6,    -1,    -1,    -1,    10,    11,    12,    -1,
      -1,    -1,    16,    17,    18,    19,    20,    -1,    -1,    -1,
      -1,    -1,    -1,    -1,     3,     4,     5,     6,    -1,    -1,
      -1,    10,    11,    12,     3,     4,     5,     6,    -1,    -1,
      -1,    10,    11,    12,    -1,    -1,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,     3,     4,     5,     6,    -1,    -1,    -1,
      10,    11,    12,    -1,    -1,    -1,    -1,     3,     4,     5,
       6,    -1,    -1,    -1,    10,    11,    12,    -1,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,
     173,    -1,   134,    -1,    -1,    -1,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,
     173,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,
      -1,   173,    -1,    -1,    -1,   134,    -1,   136,   137,    -1,
      -1,   140,    -1,   142,    -1,   144,    -1,    -1,    -1,   173,
     149,   150,   151,   152,   153,   154,   155,   156,   157,   158,
     159,   160,   161,   162,   163,   164,   165,   137,    -1,    -1,
     140,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,   149,
      -1,   151,   138,   139,    -1,    -1,    -1,    -1,    -1,   145,
     146,   147
};

/* YYSTOS[STATE-NUM] -- The (internal number of the) accessing
   symbol of state STATE-NUM.  */
static const yytype_uint8 yystos[] =
{
       0,     7,    13,    22,    25,    26,    27,    28,    29,    30,
      31,    32,    33,    34,    35,    36,    37,    38,    39,    40,
      41,    42,    43,    44,    47,    48,    49,    50,    51,    53,
      54,    55,    56,    57,    58,    59,    60,    61,    62,    63,
      64,    65,    66,    67,    68,    69,    70,    71,    72,    73,
      74,    75,    76,    77,    78,    79,    80,    81,    82,    83,
      84,    85,    86,    87,    88,    89,    90,    91,    92,    93,
      94,    95,    96,    97,    98,    99,   100,   101,   102,   103,
     104,   105,   106,   107,   108,   109,   110,   111,   112,   113,
     114,   115,   116,   117,   118,   120,   121,   122,   123,   124,
     125,   133,   172,   180,   181,   193,   194,   196,   197,   198,
     199,   200,   202,   203,   204,   205,   206,   207,   208,   209,
     210,   245,     3,     4,     5,     6,    10,    11,    12,    16,
      17,    18,    19,    20,   176,   188,   218,   228,   231,   239,
     242,   243,     1,    22,    23,   182,   195,     1,   169,   214,
     182,   195,   182,   195,   195,   231,   231,   140,   195,   227,
     195,   227,   214,   214,   214,   214,   214,     1,     4,    10,
      11,    12,   221,   240,     9,   173,   224,   226,   228,   229,
     230,   243,   224,   224,   195,   226,   228,   195,   218,   219,
     220,   228,   178,   195,   178,   195,   223,   224,   226,    14,
     195,   216,   217,   195,   217,   195,   226,   224,   214,   214,
     195,     1,   195,   221,   221,   221,   226,   195,   223,   195,
     227,   195,   227,   231,   195,   228,   170,   195,   211,   195,
     217,   211,   195,   171,   213,   174,   195,   228,   214,   228,
     214,   228,   226,   173,   228,   195,   228,   195,   228,   214,
     195,   214,   195,   223,   195,   223,   195,   223,   195,   223,
     226,   195,   211,   214,   214,   195,   226,   195,   223,   175,
     195,   195,   195,   214,   195,   170,   212,   213,   213,   168,
     168,   214,   214,   214,   231,   195,   227,   227,   195,   227,
     195,   195,   243,   243,   195,   227,   195,   195,   227,   214,
     212,     1,   195,   215,   240,   119,   195,   195,   214,   214,
     182,   195,   182,   195,   126,   127,   128,   130,   131,   132,
     182,   195,    21,   134,   136,   137,   140,   142,   144,   149,
     150,   151,   152,   153,   154,   155,   156,   157,   158,   159,
     160,   161,   162,   163,   164,   165,   243,   247,   195,   221,
     195,   221,     0,   196,    22,   231,   176,   184,   185,   186,
     187,   195,   195,   195,   195,   195,   231,   231,   231,   231,
       1,   215,   215,     1,   215,   215,   215,   195,   227,   227,
     227,   227,   227,   227,   195,   227,    21,   140,   195,   195,
     195,   227,   195,    14,   223,   223,   195,   227,   195,   195,
     195,    15,     1,   227,   195,   201,   195,   231,   231,   195,
     195,   195,   223,   195,   195,   195,   195,   227,   195,   227,
     195,   227,   227,   195,   227,   195,   195,   195,   195,   195,
     195,   195,   195,   168,   235,   236,   243,   195,   215,   215,
     195,   195,   195,   195,   227,   195,   195,   195,   195,   168,
     195,   195,   231,   195,   231,   231,   231,   195,   195,   243,
     228,   240,   231,   227,   195,   195,   195,   195,   227,   195,
     227,   195,   195,   240,   241,   222,   240,   226,   226,   240,
     226,   195,   226,   156,   157,   158,   159,   160,   161,   243,
     243,   140,   138,   139,   145,   146,   167,   248,   249,   137,
     140,   149,   151,   243,   243,   140,   140,   140,   195,   195,
       1,   189,   231,   231,   231,   231,   225,   227,   226,   195,
     195,   225,   225,     1,   224,   225,     1,   226,   231,   168,
     183,   237,   238,   243,   226,     9,   229,   235,   226,   243,
     220,   223,    15,   232,   232,   226,   134,   190,   218,   233,
     234,   243,   195,   168,   244,   245,   246,   195,   195,   232,
     174,   214,   214,   173,   173,   195,   227,     1,   226,     1,
     224,   231,   195,   195,   195,   195,   195,   195,   195,   227,
     195,   227,   195,   223,   231,   243,   243,   195,   129,   195,
     195,   195,   195,   195,    24,   195,   135,   135,   135,   135,
     135,   135,   135,   140,   248,   167,   248,   166,   140,   167,
     248,   140,   140,   140,   143,   248,   248,   138,   139,   146,
     147,   243,   249,   195,   226,   195,   195,   195,   195,   195,
     195,   195,   195,   238,   195,   195,   195,   233,   195,   195,
     195,   233,   174,   177,   195,   195,   141,   141,   195,   195,
     195,   195,   195,   195,   195,   236,   195,   195,   195,   228,
     228,   195,   195,   195,   195,   240,   195,   140,   138,   146,
     248,   166,   248,   167,   248,   143,   166,   248,   248,   147,
     248,   140,     1,   135,   191,     1,   233,   245,   245,   195,
     227,   195,   227,   195,   137,   139,   158,   159,   160,   135,
     135,   143,   248,   143,   143,   166,   143,   143,   143,   143,
     139,   134,   226,   228,   228,   140,   143,   143,   233,   195,
     227,   195,   227,   139,   135,   228,   228,   195,   227,   195,
     227,   228,   228,   195,   195,   227,   228,   195
};

#define yyerrok		(yyerrstatus = 0)
#define yyclearin	(yychar = YYEMPTY)
#define YYEMPTY		(-2)
#define YYEOF		0

#define YYACCEPT	goto yyacceptlab
#define YYABORT		goto yyabortlab
#define YYERROR		goto yyerrorlab


/* Like YYERROR except do call yyerror.  This remains here temporarily
   to ease the transition to the new meaning of YYERROR, for GCC.
   Once GCC version 2 has supplanted version 1, this can go.  */

#define YYFAIL		goto yyerrlab

#define YYRECOVERING()  (!!yyerrstatus)

#define YYBACKUP(Token, Value)					\
do								\
  if (yychar == YYEMPTY && yylen == 1)				\
    {								\
      yychar = (Token);						\
      yylval = (Value);						\
      yytoken = YYTRANSLATE (yychar);				\
      YYPOPSTACK (1);						\
      goto yybackup;						\
    }								\
  else								\
    {								\
      yyerror (YY_("syntax error: cannot back up")); \
      YYERROR;							\
    }								\
while (YYID (0))


#define YYTERROR	1
#define YYERRCODE	256


/* YYLLOC_DEFAULT -- Set CURRENT to span from RHS[1] to RHS[N].
   If N is 0, then set CURRENT to the empty location which ends
   the previous symbol: RHS[0] (always defined).  */

#define YYRHSLOC(Rhs, K) ((Rhs)[K])
#ifndef YYLLOC_DEFAULT
# define YYLLOC_DEFAULT(Current, Rhs, N)				\
    do									\
      if (YYID (N))                                                    \
	{								\
	  (Current).first_line   = YYRHSLOC (Rhs, 1).first_line;	\
	  (Current).first_column = YYRHSLOC (Rhs, 1).first_column;	\
	  (Current).last_line    = YYRHSLOC (Rhs, N).last_line;		\
	  (Current).last_column  = YYRHSLOC (Rhs, N).last_column;	\
	}								\
      else								\
	{								\
	  (Current).first_line   = (Current).last_line   =		\
	    YYRHSLOC (Rhs, 0).last_line;				\
	  (Current).first_column = (Current).last_column =		\
	    YYRHSLOC (Rhs, 0).last_column;				\
	}								\
    while (YYID (0))
#endif


/* YY_LOCATION_PRINT -- Print the location on the stream.
   This macro was not mandated originally: define only if we know
   we won't break user code: when these are the locations we know.  */

#ifndef YY_LOCATION_PRINT
# if defined YYLTYPE_IS_TRIVIAL && YYLTYPE_IS_TRIVIAL
#  define YY_LOCATION_PRINT(File, Loc)			\
     fprintf (File, "%d.%d-%d.%d",			\
	      (Loc).first_line, (Loc).first_column,	\
	      (Loc).last_line,  (Loc).last_column)
# else
#  define YY_LOCATION_PRINT(File, Loc) ((void) 0)
# endif
#endif


/* YYLEX -- calling `yylex' with the right arguments.  */

#ifdef YYLEX_PARAM
# define YYLEX yylex (YYLEX_PARAM)
#else
# define YYLEX yylex ()
#endif

/* Enable debugging if requested.  */
#if YYDEBUG

# ifndef YYFPRINTF
#  include <stdio.h> /* INFRINGES ON USER NAME SPACE */
#  define YYFPRINTF fprintf
# endif

# define YYDPRINTF(Args)			\
do {						\
  if (yydebug)					\
    YYFPRINTF Args;				\
} while (YYID (0))

# define YY_SYMBOL_PRINT(Title, Type, Value, Location)			  \
do {									  \
  if (yydebug)								  \
    {									  \
      YYFPRINTF (stderr, "%s ", Title);					  \
      yy_symbol_print (stderr,						  \
		  Type, Value); \
      YYFPRINTF (stderr, "\n");						  \
    }									  \
} while (YYID (0))


/*--------------------------------.
| Print this symbol on YYOUTPUT.  |
`--------------------------------*/

/*ARGSUSED*/
#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
static void
yy_symbol_value_print (FILE *yyoutput, int yytype, YYSTYPE const * const yyvaluep)
#else
static void
yy_symbol_value_print (yyoutput, yytype, yyvaluep)
    FILE *yyoutput;
    int yytype;
    YYSTYPE const * const yyvaluep;
#endif
{
  if (!yyvaluep)
    return;
# ifdef YYPRINT
  if (yytype < YYNTOKENS)
    YYPRINT (yyoutput, yytoknum[yytype], *yyvaluep);
# else
  YYUSE (yyoutput);
# endif
  switch (yytype)
    {
      default:
	break;
    }
}


/*--------------------------------.
| Print this symbol on YYOUTPUT.  |
`--------------------------------*/

#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
static void
yy_symbol_print (FILE *yyoutput, int yytype, YYSTYPE const * const yyvaluep)
#else
static void
yy_symbol_print (yyoutput, yytype, yyvaluep)
    FILE *yyoutput;
    int yytype;
    YYSTYPE const * const yyvaluep;
#endif
{
  if (yytype < YYNTOKENS)
    YYFPRINTF (yyoutput, "token %s (", yytname[yytype]);
  else
    YYFPRINTF (yyoutput, "nterm %s (", yytname[yytype]);

  yy_symbol_value_print (yyoutput, yytype, yyvaluep);
  YYFPRINTF (yyoutput, ")");
}

/*------------------------------------------------------------------.
| yy_stack_print -- Print the state stack from its BOTTOM up to its |
| TOP (included).                                                   |
`------------------------------------------------------------------*/

#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
static void
yy_stack_print (yytype_int16 *bottom, yytype_int16 *top)
#else
static void
yy_stack_print (bottom, top)
    yytype_int16 *bottom;
    yytype_int16 *top;
#endif
{
  YYFPRINTF (stderr, "Stack now");
  for (; bottom <= top; ++bottom)
    YYFPRINTF (stderr, " %d", *bottom);
  YYFPRINTF (stderr, "\n");
}

# define YY_STACK_PRINT(Bottom, Top)				\
do {								\
  if (yydebug)							\
    yy_stack_print ((Bottom), (Top));				\
} while (YYID (0))


/*------------------------------------------------.
| Report that the YYRULE is going to be reduced.  |
`------------------------------------------------*/

#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
static void
yy_reduce_print (YYSTYPE *yyvsp, int yyrule)
#else
static void
yy_reduce_print (yyvsp, yyrule)
    YYSTYPE *yyvsp;
    int yyrule;
#endif
{
  int yynrhs = yyr2[yyrule];
  int yyi;
  unsigned long int yylno = yyrline[yyrule];
  YYFPRINTF (stderr, "Reducing stack by rule %d (line %lu):\n",
	     yyrule - 1, yylno);
  /* The symbols being reduced.  */
  for (yyi = 0; yyi < yynrhs; yyi++)
    {
      fprintf (stderr, "   $%d = ", yyi + 1);
      yy_symbol_print (stderr, yyrhs[yyprhs[yyrule] + yyi],
		       &(yyvsp[(yyi + 1) - (yynrhs)])
		       		       );
      fprintf (stderr, "\n");
    }
}

# define YY_REDUCE_PRINT(Rule)		\
do {					\
  if (yydebug)				\
    yy_reduce_print (yyvsp, Rule); \
} while (YYID (0))

/* Nonzero means print parse trace.  It is left uninitialized so that
   multiple parsers can coexist.  */
int yydebug;
#else /* !YYDEBUG */
# define YYDPRINTF(Args)
# define YY_SYMBOL_PRINT(Title, Type, Value, Location)
# define YY_STACK_PRINT(Bottom, Top)
# define YY_REDUCE_PRINT(Rule)
#endif /* !YYDEBUG */


/* YYINITDEPTH -- initial size of the parser's stacks.  */
#ifndef	YYINITDEPTH
# define YYINITDEPTH 200
#endif

/* YYMAXDEPTH -- maximum size the stacks can grow to (effective only
   if the built-in stack extension method is used).

   Do not make this value too large; the results are undefined if
   YYSTACK_ALLOC_MAXIMUM < YYSTACK_BYTES (YYMAXDEPTH)
   evaluated with infinite-precision integer arithmetic.  */

#ifndef YYMAXDEPTH
# define YYMAXDEPTH 10000
#endif



#if YYERROR_VERBOSE

# ifndef yystrlen
#  if defined __GLIBC__ && defined _STRING_H
#   define yystrlen strlen
#  else
/* Return the length of YYSTR.  */
#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
static YYSIZE_T
yystrlen (const char *yystr)
#else
static YYSIZE_T
yystrlen (yystr)
    const char *yystr;
#endif
{
  YYSIZE_T yylen;
  for (yylen = 0; yystr[yylen]; yylen++)
    continue;
  return yylen;
}
#  endif
# endif

# ifndef yystpcpy
#  if defined __GLIBC__ && defined _STRING_H && defined _GNU_SOURCE
#   define yystpcpy stpcpy
#  else
/* Copy YYSRC to YYDEST, returning the address of the terminating '\0' in
   YYDEST.  */
#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
static char *
yystpcpy (char *yydest, const char *yysrc)
#else
static char *
yystpcpy (yydest, yysrc)
    char *yydest;
    const char *yysrc;
#endif
{
  char *yyd = yydest;
  const char *yys = yysrc;

  while ((*yyd++ = *yys++) != '\0')
    continue;

  return yyd - 1;
}
#  endif
# endif

# ifndef yytnamerr
/* Copy to YYRES the contents of YYSTR after stripping away unnecessary
   quotes and backslashes, so that it's suitable for yyerror.  The
   heuristic is that double-quoting is unnecessary unless the string
   contains an apostrophe, a comma, or backslash (other than
   backslash-backslash).  YYSTR is taken from yytname.  If YYRES is
   null, do not copy; instead, return the length of what the result
   would have been.  */
static YYSIZE_T
yytnamerr (char *yyres, const char *yystr)
{
  if (*yystr == '"')
    {
      YYSIZE_T yyn = 0;
      char const *yyp = yystr;

      for (;;)
	switch (*++yyp)
	  {
	  case '\'':
	  case ',':
	    goto do_not_strip_quotes;

	  case '\\':
	    if (*++yyp != '\\')
	      goto do_not_strip_quotes;
	    /* Fall through.  */
	  default:
	    if (yyres)
	      yyres[yyn] = *yyp;
	    yyn++;
	    break;

	  case '"':
	    if (yyres)
	      yyres[yyn] = '\0';
	    return yyn;
	  }
    do_not_strip_quotes: ;
    }

  if (! yyres)
    return yystrlen (yystr);

  return yystpcpy (yyres, yystr) - yyres;
}
# endif

/* Copy into YYRESULT an error message about the unexpected token
   YYCHAR while in state YYSTATE.  Return the number of bytes copied,
   including the terminating null byte.  If YYRESULT is null, do not
   copy anything; just return the number of bytes that would be
   copied.  As a special case, return 0 if an ordinary "syntax error"
   message will do.  Return YYSIZE_MAXIMUM if overflow occurs during
   size calculation.  */
static YYSIZE_T
yysyntax_error (char *yyresult, int yystate, int yychar)
{
  int yyn = yypact[yystate];

  if (! (YYPACT_NINF < yyn && yyn <= YYLAST))
    return 0;
  else
    {
      int yytype = YYTRANSLATE (yychar);
      YYSIZE_T yysize0 = yytnamerr (0, yytname[yytype]);
      YYSIZE_T yysize = yysize0;
      YYSIZE_T yysize1;
      int yysize_overflow = 0;
      enum { YYERROR_VERBOSE_ARGS_MAXIMUM = 5 };
      char const *yyarg[YYERROR_VERBOSE_ARGS_MAXIMUM];
      int yyx;

# if 0
      /* This is so xgettext sees the translatable formats that are
	 constructed on the fly.  */
      YY_("syntax error, unexpected %s");
      YY_("syntax error, unexpected %s, expecting %s");
      YY_("syntax error, unexpected %s, expecting %s or %s");
      YY_("syntax error, unexpected %s, expecting %s or %s or %s");
      YY_("syntax error, unexpected %s, expecting %s or %s or %s or %s");
# endif
      char *yyfmt;
      char const *yyf;
      static char const yyunexpected[] = "syntax error, unexpected %s";
      static char const yyexpecting[] = ", expecting %s";
      static char const yyor[] = " or %s";
      char yyformat[sizeof yyunexpected
		    + sizeof yyexpecting - 1
		    + ((YYERROR_VERBOSE_ARGS_MAXIMUM - 2)
		       * (sizeof yyor - 1))];
      char const *yyprefix = yyexpecting;

      /* Start YYX at -YYN if negative to avoid negative indexes in
	 YYCHECK.  */
      int yyxbegin = yyn < 0 ? -yyn : 0;

      /* Stay within bounds of both yycheck and yytname.  */
      int yychecklim = YYLAST - yyn + 1;
      int yyxend = yychecklim < YYNTOKENS ? yychecklim : YYNTOKENS;
      int yycount = 1;

      yyarg[0] = yytname[yytype];
      yyfmt = yystpcpy (yyformat, yyunexpected);

      for (yyx = yyxbegin; yyx < yyxend; ++yyx)
	if (yycheck[yyx + yyn] == yyx && yyx != YYTERROR)
	  {
	    if (yycount == YYERROR_VERBOSE_ARGS_MAXIMUM)
	      {
		yycount = 1;
		yysize = yysize0;
		yyformat[sizeof yyunexpected - 1] = '\0';
		break;
	      }
	    yyarg[yycount++] = yytname[yyx];
	    yysize1 = yysize + yytnamerr (0, yytname[yyx]);
	    yysize_overflow |= (yysize1 < yysize);
	    yysize = yysize1;
	    yyfmt = yystpcpy (yyfmt, yyprefix);
	    yyprefix = yyor;
	  }

      yyf = YY_(yyformat);
      yysize1 = yysize + yystrlen (yyf);
      yysize_overflow |= (yysize1 < yysize);
      yysize = yysize1;

      if (yysize_overflow)
	return YYSIZE_MAXIMUM;

      if (yyresult)
	{
	  /* Avoid sprintf, as that infringes on the user's name space.
	     Don't have undefined behavior even if the translation
	     produced a string with the wrong number of "%s"s.  */
	  char *yyp = yyresult;
	  int yyi = 0;
	  while ((*yyp = *yyf) != '\0')
	    {
	      if (*yyp == '%' && yyf[1] == 's' && yyi < yycount)
		{
		  yyp += yytnamerr (yyp, yyarg[yyi++]);
		  yyf += 2;
		}
	      else
		{
		  yyp++;
		  yyf++;
		}
	    }
	}
      return yysize;
    }
}
#endif /* YYERROR_VERBOSE */


/*-----------------------------------------------.
| Release the memory associated to this symbol.  |
`-----------------------------------------------*/

/*ARGSUSED*/
#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
static void
yydestruct (const char *yymsg, int yytype, YYSTYPE *yyvaluep)
#else
static void
yydestruct (yymsg, yytype, yyvaluep)
    const char *yymsg;
    int yytype;
    YYSTYPE *yyvaluep;
#endif
{
  YYUSE (yyvaluep);

  if (!yymsg)
    yymsg = "Deleting";
  YY_SYMBOL_PRINT (yymsg, yytype, yyvaluep, yylocationp);

  switch (yytype)
    {

      default:
	break;
    }
}


/* Prevent warnings from -Wmissing-prototypes.  */

#ifdef YYPARSE_PARAM
#if defined __STDC__ || defined __cplusplus
int yyparse (void *YYPARSE_PARAM);
#else
int yyparse ();
#endif
#else /* ! YYPARSE_PARAM */
#if defined __STDC__ || defined __cplusplus
int yyparse (void);
#else
int yyparse ();
#endif
#endif /* ! YYPARSE_PARAM */



/* The look-ahead symbol.  */
int yychar;

/* The semantic value of the look-ahead symbol.  */
YYSTYPE yylval;

/* Number of syntax errors so far.  */
int yynerrs;



/*----------.
| yyparse.  |
`----------*/

#ifdef YYPARSE_PARAM
#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
int
yyparse (void *YYPARSE_PARAM)
#else
int
yyparse (YYPARSE_PARAM)
    void *YYPARSE_PARAM;
#endif
#else /* ! YYPARSE_PARAM */
#if (defined __STDC__ || defined __C99__FUNC__ \
     || defined __cplusplus || defined _MSC_VER)
int
yyparse (void)
#else
int
yyparse ()

#endif
#endif
{
  
  int yystate;
  int yyn;
  int yyresult;
  /* Number of tokens to shift before error messages enabled.  */
  int yyerrstatus;
  /* Look-ahead token as an internal (translated) token number.  */
  int yytoken = 0;
#if YYERROR_VERBOSE
  /* Buffer for error messages, and its allocated size.  */
  char yymsgbuf[128];
  char *yymsg = yymsgbuf;
  YYSIZE_T yymsg_alloc = sizeof yymsgbuf;
#endif

  /* Three stacks and their tools:
     `yyss': related to states,
     `yyvs': related to semantic values,
     `yyls': related to locations.

     Refer to the stacks thru separate pointers, to allow yyoverflow
     to reallocate them elsewhere.  */

  /* The state stack.  */
  yytype_int16 yyssa[YYINITDEPTH];
  yytype_int16 *yyss = yyssa;
  yytype_int16 *yyssp;

  /* The semantic value stack.  */
  YYSTYPE yyvsa[YYINITDEPTH];
  YYSTYPE *yyvs = yyvsa;
  YYSTYPE *yyvsp;



#define YYPOPSTACK(N)   (yyvsp -= (N), yyssp -= (N))

  YYSIZE_T yystacksize = YYINITDEPTH;

  /* The variables used to return semantic value and location from the
     action routines.  */
  YYSTYPE yyval;


  /* The number of symbols on the RHS of the reduced rule.
     Keep to zero when no symbol should be popped.  */
  int yylen = 0;

  YYDPRINTF ((stderr, "Starting parse\n"));

  yystate = 0;
  yyerrstatus = 0;
  yynerrs = 0;
  yychar = YYEMPTY;		/* Cause a token to be read.  */

  /* Initialize stack pointers.
     Waste one element of value and location stack
     so that they stay on the same level as the state stack.
     The wasted elements are never initialized.  */

  yyssp = yyss;
  yyvsp = yyvs;

  goto yysetstate;

/*------------------------------------------------------------.
| yynewstate -- Push a new state, which is found in yystate.  |
`------------------------------------------------------------*/
 yynewstate:
  /* In all cases, when you get here, the value and location stacks
     have just been pushed.  So pushing a state here evens the stacks.  */
  yyssp++;

 yysetstate:
  *yyssp = yystate;

  if (yyss + yystacksize - 1 <= yyssp)
    {
      /* Get the current used size of the three stacks, in elements.  */
      YYSIZE_T yysize = yyssp - yyss + 1;

#ifdef yyoverflow
      {
	/* Give user a chance to reallocate the stack.  Use copies of
	   these so that the &'s don't force the real ones into
	   memory.  */
	YYSTYPE *yyvs1 = yyvs;
	yytype_int16 *yyss1 = yyss;


	/* Each stack pointer address is followed by the size of the
	   data in use in that stack, in bytes.  This used to be a
	   conditional around just the two extra args, but that might
	   be undefined if yyoverflow is a macro.  */
	yyoverflow (YY_("memory exhausted"),
		    &yyss1, yysize * sizeof (*yyssp),
		    &yyvs1, yysize * sizeof (*yyvsp),

		    &yystacksize);

	yyss = yyss1;
	yyvs = yyvs1;
      }
#else /* no yyoverflow */
# ifndef YYSTACK_RELOCATE
      goto yyexhaustedlab;
# else
      /* Extend the stack our own way.  */
      if (YYMAXDEPTH <= yystacksize)
	goto yyexhaustedlab;
      yystacksize *= 2;
      if (YYMAXDEPTH < yystacksize)
	yystacksize = YYMAXDEPTH;

      {
	yytype_int16 *yyss1 = yyss;
	union yyalloc *yyptr =
	  (union yyalloc *) YYSTACK_ALLOC (YYSTACK_BYTES (yystacksize));
	if (! yyptr)
	  goto yyexhaustedlab;
	YYSTACK_RELOCATE (yyss);
	YYSTACK_RELOCATE (yyvs);

#  undef YYSTACK_RELOCATE
	if (yyss1 != yyssa)
	  YYSTACK_FREE (yyss1);
      }
# endif
#endif /* no yyoverflow */

      yyssp = yyss + yysize - 1;
      yyvsp = yyvs + yysize - 1;


      YYDPRINTF ((stderr, "Stack size increased to %lu\n",
		  (unsigned long int) yystacksize));

      if (yyss + yystacksize - 1 <= yyssp)
	YYABORT;
    }

  YYDPRINTF ((stderr, "Entering state %d\n", yystate));

  goto yybackup;

/*-----------.
| yybackup.  |
`-----------*/
yybackup:

  /* Do appropriate processing given the current state.  Read a
     look-ahead token if we need one and don't already have one.  */

  /* First try to decide what to do without reference to look-ahead token.  */
  yyn = yypact[yystate];
  if (yyn == YYPACT_NINF)
    goto yydefault;

  /* Not known => get a look-ahead token if don't already have one.  */

  /* YYCHAR is either YYEMPTY or YYEOF or a valid look-ahead symbol.  */
  if (yychar == YYEMPTY)
    {
      YYDPRINTF ((stderr, "Reading a token: "));
      yychar = YYLEX;
    }

  if (yychar <= YYEOF)
    {
      yychar = yytoken = YYEOF;
      YYDPRINTF ((stderr, "Now at end of input.\n"));
    }
  else
    {
      yytoken = YYTRANSLATE (yychar);
      YY_SYMBOL_PRINT ("Next token is", yytoken, &yylval, &yylloc);
    }

  /* If the proper action on seeing token YYTOKEN is to reduce or to
     detect an error, take that action.  */
  yyn += yytoken;
  if (yyn < 0 || YYLAST < yyn || yycheck[yyn] != yytoken)
    goto yydefault;
  yyn = yytable[yyn];
  if (yyn <= 0)
    {
      if (yyn == 0 || yyn == YYTABLE_NINF)
	goto yyerrlab;
      yyn = -yyn;
      goto yyreduce;
    }

  if (yyn == YYFINAL)
    YYACCEPT;

  /* Count tokens shifted since error; after three, turn off error
     status.  */
  if (yyerrstatus)
    yyerrstatus--;

  /* Shift the look-ahead token.  */
  YY_SYMBOL_PRINT ("Shifting", yytoken, &yylval, &yylloc);

  /* Discard the shifted token unless it is eof.  */
  if (yychar != YYEOF)
    yychar = YYEMPTY;

  yystate = yyn;
  *++yyvsp = yylval;

  goto yynewstate;


/*-----------------------------------------------------------.
| yydefault -- do the default action for the current state.  |
`-----------------------------------------------------------*/
yydefault:
  yyn = yydefact[yystate];
  if (yyn == 0)
    goto yyerrlab;
  goto yyreduce;


/*-----------------------------.
| yyreduce -- Do a reduction.  |
`-----------------------------*/
yyreduce:
  /* yyn is the number of a rule to reduce with.  */
  yylen = yyr2[yyn];

  /* If YYLEN is nonzero, implement the default value of the action:
     `$$ = $1'.

     Otherwise, the following line sets YYVAL to garbage.
     This behavior is undocumented and Bison
     users should not rely upon it.  Assigning to YYVAL
     unconditionally makes the parser a bit smaller, and it avoids a
     GCC warning that YYVAL may be used uninitialized.  */
  yyval = yyvsp[1-yylen];


  YY_REDUCE_PRINT (yyn);
  switch (yyn)
    {
        case 2:
#line 189 "mon_parse.y"
    { (yyval.i) = 0; }
    break;

  case 3:
#line 190 "mon_parse.y"
    { (yyval.i) = 0; }
    break;

  case 4:
#line 191 "mon_parse.y"
    { new_cmd = 1; asm_mode = 0;  (yyval.i) = 0; }
    break;

  case 9:
#line 200 "mon_parse.y"
    { return ERR_EXPECT_END_CMD; }
    break;

  case 22:
#line 215 "mon_parse.y"
    { return ERR_BAD_CMD; }
    break;

  case 23:
#line 219 "mon_parse.y"
    { mon_bank(e_default_space, NULL); }
    break;

  case 24:
#line 221 "mon_parse.y"
    { mon_bank((yyvsp[(2) - (3)].i), NULL); }
    break;

  case 25:
#line 223 "mon_parse.y"
    { mon_bank(e_default_space, (yyvsp[(2) - (3)].str)); }
    break;

  case 26:
#line 225 "mon_parse.y"
    { mon_bank((yyvsp[(2) - (5)].i), (yyvsp[(4) - (5)].str)); }
    break;

  case 27:
#line 227 "mon_parse.y"
    { mon_jump((yyvsp[(2) - (3)].a)); }
    break;

  case 28:
#line 229 "mon_parse.y"
    { mon_go(); }
    break;

  case 29:
#line 231 "mon_parse.y"
    { mon_display_io_regs(0); }
    break;

  case 30:
#line 233 "mon_parse.y"
    { mon_display_io_regs((yyvsp[(2) - (3)].a)); }
    break;

  case 31:
#line 235 "mon_parse.y"
    { monitor_cpu_type_set(""); }
    break;

  case 32:
#line 237 "mon_parse.y"
    { monitor_cpu_type_set((yyvsp[(2) - (3)].str)); }
    break;

  case 33:
#line 239 "mon_parse.y"
    { mon_cpuhistory(-1, e_invalid_space,  e_invalid_space, e_invalid_space, e_invalid_space, e_invalid_space); }
    break;

  case 34:
#line 241 "mon_parse.y"
    { mon_cpuhistory(-1, (yyvsp[(3) - (4)].i), e_invalid_space, e_invalid_space, e_invalid_space, e_invalid_space); }
    break;

  case 35:
#line 243 "mon_parse.y"
    { mon_cpuhistory(-1, (yyvsp[(3) - (6)].i), (yyvsp[(5) - (6)].i), e_invalid_space, e_invalid_space, e_invalid_space); }
    break;

  case 36:
#line 245 "mon_parse.y"
    { mon_cpuhistory(-1, (yyvsp[(3) - (8)].i), (yyvsp[(5) - (8)].i), (yyvsp[(7) - (8)].i), e_invalid_space, e_invalid_space); }
    break;

  case 37:
#line 247 "mon_parse.y"
    { mon_cpuhistory(-1, (yyvsp[(3) - (10)].i), (yyvsp[(5) - (10)].i), (yyvsp[(7) - (10)].i),  (yyvsp[(9) - (10)].i), e_invalid_space); }
    break;

  case 38:
#line 249 "mon_parse.y"
    { mon_cpuhistory(-1, (yyvsp[(3) - (12)].i), (yyvsp[(5) - (12)].i), (yyvsp[(7) - (12)].i),  (yyvsp[(9) - (12)].i), (yyvsp[(11) - (12)].i)); }
    break;

  case 39:
#line 251 "mon_parse.y"
    { mon_cpuhistory((yyvsp[(3) - (4)].i), e_invalid_space, e_invalid_space, e_invalid_space, e_invalid_space, e_invalid_space); }
    break;

  case 40:
#line 253 "mon_parse.y"
    { mon_cpuhistory((yyvsp[(3) - (6)].i), (yyvsp[(5) - (6)].i), e_invalid_space, e_invalid_space, e_invalid_space, e_invalid_space); }
    break;

  case 41:
#line 255 "mon_parse.y"
    { mon_cpuhistory((yyvsp[(3) - (8)].i), (yyvsp[(5) - (8)].i), (yyvsp[(7) - (8)].i), e_invalid_space, e_invalid_space, e_invalid_space); }
    break;

  case 42:
#line 257 "mon_parse.y"
    { mon_cpuhistory((yyvsp[(3) - (10)].i), (yyvsp[(5) - (10)].i), (yyvsp[(7) - (10)].i), (yyvsp[(9) - (10)].i), e_invalid_space, e_invalid_space); }
    break;

  case 43:
#line 259 "mon_parse.y"
    { mon_cpuhistory((yyvsp[(3) - (12)].i), (yyvsp[(5) - (12)].i), (yyvsp[(7) - (12)].i), (yyvsp[(9) - (12)].i), (yyvsp[(11) - (12)].i), e_invalid_space); }
    break;

  case 44:
#line 261 "mon_parse.y"
    { mon_cpuhistory((yyvsp[(3) - (14)].i), (yyvsp[(5) - (14)].i), (yyvsp[(7) - (14)].i), (yyvsp[(9) - (14)].i), (yyvsp[(11) - (14)].i), (yyvsp[(13) - (14)].i)); }
    break;

  case 45:
#line 263 "mon_parse.y"
    { mon_instruction_return(); }
    break;

  case 46:
#line 265 "mon_parse.y"
    { mon_write_snapshot((yyvsp[(2) - (3)].str),0,0,0); /* FIXME */ }
    break;

  case 47:
#line 267 "mon_parse.y"
    { mon_read_snapshot((yyvsp[(2) - (3)].str), 0); }
    break;

  case 48:
#line 269 "mon_parse.y"
    { mon_instructions_step(-1); }
    break;

  case 49:
#line 271 "mon_parse.y"
    { mon_instructions_step((yyvsp[(3) - (4)].i)); }
    break;

  case 50:
#line 273 "mon_parse.y"
    { mon_instructions_next(-1); }
    break;

  case 51:
#line 275 "mon_parse.y"
    { mon_instructions_next((yyvsp[(3) - (4)].i)); }
    break;

  case 52:
#line 277 "mon_parse.y"
    { mon_stack_up(-1); }
    break;

  case 53:
#line 279 "mon_parse.y"
    { mon_stack_up((yyvsp[(3) - (4)].i)); }
    break;

  case 54:
#line 281 "mon_parse.y"
    { mon_stack_down(-1); }
    break;

  case 55:
#line 283 "mon_parse.y"
    { mon_stack_down((yyvsp[(3) - (4)].i)); }
    break;

  case 56:
#line 285 "mon_parse.y"
    { mon_display_screen(-1); }
    break;

  case 57:
#line 287 "mon_parse.y"
    { mon_display_screen((yyvsp[(2) - (3)].a)); }
    break;

  case 58:
#line 289 "mon_parse.y"
    {
                        mon_out("Warp mode is %s.\n",
                                vsync_get_warp_mode() ? "on" : "off");
                     }
    break;

  case 59:
#line 294 "mon_parse.y"
    {
                        vsync_set_warp_mode((((yyvsp[(2) - (3)].action) == e_TOGGLE) ? (vsync_get_warp_mode() ^ 1) : (yyvsp[(2) - (3)].action)));
                     }
    break;

  case 61:
#line 301 "mon_parse.y"
    { (monitor_cpu_for_memspace[default_memspace]->mon_register_print)(default_memspace); }
    break;

  case 62:
#line 303 "mon_parse.y"
    { (monitor_cpu_for_memspace[(yyvsp[(2) - (3)].i)]->mon_register_print)((yyvsp[(2) - (3)].i)); }
    break;

  case 64:
#line 308 "mon_parse.y"
    {
                        /* What about the memspace? */
                        mon_playback_commands((yyvsp[(4) - (5)].str),true);
                    }
    break;

  case 65:
#line 313 "mon_parse.y"
    {
                        /* What about the memspace? */
                        mon_playback_commands((yyvsp[(2) - (3)].str),true);
                    }
    break;

  case 66:
#line 318 "mon_parse.y"
    { mon_save_symbols((yyvsp[(2) - (5)].i), (yyvsp[(4) - (5)].str)); }
    break;

  case 67:
#line 320 "mon_parse.y"
    { mon_save_symbols(e_default_space, (yyvsp[(2) - (3)].str)); }
    break;

  case 68:
#line 322 "mon_parse.y"
    { mon_add_name_to_symbol_table((yyvsp[(2) - (5)].a), (yyvsp[(4) - (5)].str)); }
    break;

  case 69:
#line 324 "mon_parse.y"
    { mon_remove_name_from_symbol_table(e_default_space, (yyvsp[(2) - (3)].str)); }
    break;

  case 70:
#line 326 "mon_parse.y"
    { mon_remove_name_from_symbol_table((yyvsp[(2) - (5)].i), (yyvsp[(4) - (5)].str)); }
    break;

  case 71:
#line 328 "mon_parse.y"
    { mon_print_symbol_table((yyvsp[(2) - (3)].i)); }
    break;

  case 72:
#line 330 "mon_parse.y"
    { mon_print_symbol_table(e_default_space); }
    break;

  case 73:
#line 332 "mon_parse.y"
    { mon_clear_symbol_table((yyvsp[(2) - (3)].i)); }
    break;

  case 74:
#line 334 "mon_parse.y"
    { mon_clear_symbol_table(e_default_space); }
    break;

  case 75:
#line 336 "mon_parse.y"
    {
                        mon_add_name_to_symbol_table((yyvsp[(3) - (4)].a), mon_prepend_dot_to_name((yyvsp[(1) - (4)].str)));
                    }
    break;

  case 76:
#line 340 "mon_parse.y"
    {
                        mon_add_name_to_symbol_table((yyvsp[(3) - (5)].a), mon_prepend_dot_to_name((yyvsp[(1) - (5)].str)));
                    }
    break;

  case 77:
#line 346 "mon_parse.y"
    { mon_start_assemble_mode((yyvsp[(2) - (2)].a), NULL); }
    break;

  case 78:
#line 347 "mon_parse.y"
    { }
    break;

  case 79:
#line 349 "mon_parse.y"
    { mon_start_assemble_mode((yyvsp[(2) - (3)].a), NULL); }
    break;

  case 80:
#line 351 "mon_parse.y"
    { mon_disassemble_lines((yyvsp[(2) - (3)].range)[0], (yyvsp[(2) - (3)].range)[1]); }
    break;

  case 81:
#line 353 "mon_parse.y"
    { mon_disassemble_lines(BAD_ADDR, BAD_ADDR); }
    break;

  case 82:
#line 357 "mon_parse.y"
    { mon_memory_move((yyvsp[(2) - (5)].range)[0], (yyvsp[(2) - (5)].range)[1], (yyvsp[(4) - (5)].a)); }
    break;

  case 83:
#line 359 "mon_parse.y"
    { mon_memory_compare((yyvsp[(2) - (5)].range)[0], (yyvsp[(2) - (5)].range)[1], (yyvsp[(4) - (5)].a)); }
    break;

  case 84:
#line 361 "mon_parse.y"
    { mon_memory_fill((yyvsp[(2) - (5)].range)[0], (yyvsp[(2) - (5)].range)[1],(unsigned char *)(yyvsp[(4) - (5)].str)); }
    break;

  case 85:
#line 363 "mon_parse.y"
    { mon_memory_hunt((yyvsp[(2) - (5)].range)[0], (yyvsp[(2) - (5)].range)[1],(unsigned char *)(yyvsp[(4) - (5)].str)); }
    break;

  case 86:
#line 365 "mon_parse.y"
    { mon_memory_display((yyvsp[(2) - (5)].rt), (yyvsp[(4) - (5)].range)[0], (yyvsp[(4) - (5)].range)[1], DF_PETSCII); }
    break;

  case 87:
#line 367 "mon_parse.y"
    { mon_memory_display(default_radix, (yyvsp[(2) - (3)].range)[0], (yyvsp[(2) - (3)].range)[1], DF_PETSCII); }
    break;

  case 88:
#line 369 "mon_parse.y"
    { mon_memory_display(default_radix, BAD_ADDR, BAD_ADDR, DF_PETSCII); }
    break;

  case 89:
#line 371 "mon_parse.y"
    { mon_memory_display_data((yyvsp[(2) - (3)].range)[0], (yyvsp[(2) - (3)].range)[1], 8, 8); }
    break;

  case 90:
#line 373 "mon_parse.y"
    { mon_memory_display_data(BAD_ADDR, BAD_ADDR, 8, 8); }
    break;

  case 91:
#line 375 "mon_parse.y"
    { mon_memory_display_data((yyvsp[(2) - (3)].range)[0], (yyvsp[(2) - (3)].range)[1], 24, 21); }
    break;

  case 92:
#line 377 "mon_parse.y"
    { mon_memory_display_data(BAD_ADDR, BAD_ADDR, 24, 21); }
    break;

  case 93:
#line 379 "mon_parse.y"
    { mon_memory_display(e_text, (yyvsp[(2) - (3)].range)[0], (yyvsp[(2) - (3)].range)[1], DF_PETSCII); }
    break;

  case 94:
#line 381 "mon_parse.y"
    { mon_memory_display(e_text, BAD_ADDR, BAD_ADDR, DF_PETSCII); }
    break;

  case 95:
#line 383 "mon_parse.y"
    { mon_memory_display(e_text, (yyvsp[(2) - (3)].range)[0], (yyvsp[(2) - (3)].range)[1], DF_SCREEN_CODE); }
    break;

  case 96:
#line 385 "mon_parse.y"
    { mon_memory_display(e_text, BAD_ADDR, BAD_ADDR, DF_SCREEN_CODE); }
    break;

  case 97:
#line 387 "mon_parse.y"
    { mon_memmap_zap(); }
    break;

  case 98:
#line 389 "mon_parse.y"
    { mon_memmap_show(-1,BAD_ADDR,BAD_ADDR); }
    break;

  case 99:
#line 391 "mon_parse.y"
    { mon_memmap_show((yyvsp[(3) - (4)].i),BAD_ADDR,BAD_ADDR); }
    break;

  case 100:
#line 393 "mon_parse.y"
    { mon_memmap_show((yyvsp[(3) - (5)].i),(yyvsp[(4) - (5)].range)[0],(yyvsp[(4) - (5)].range)[1]); }
    break;

  case 101:
#line 395 "mon_parse.y"
    { mon_memmap_save((yyvsp[(2) - (5)].str),(yyvsp[(4) - (5)].i)); }
    break;

  case 102:
#line 399 "mon_parse.y"
    {
                      if ((yyvsp[(2) - (5)].i)) {
                          temp = mon_breakpoint_add_checkpoint((yyvsp[(3) - (5)].range)[0], (yyvsp[(3) - (5)].range)[1], TRUE, (yyvsp[(2) - (5)].i), FALSE, TRUE);
                      } else {
                          temp = mon_breakpoint_add_checkpoint((yyvsp[(3) - (5)].range)[0], (yyvsp[(3) - (5)].range)[1], TRUE, e_exec, FALSE, TRUE);
                      }
                      mon_breakpoint_set_checkpoint_condition(temp, (yyvsp[(4) - (5)].cond_node));
                  }
    break;

  case 103:
#line 408 "mon_parse.y"
    { mon_breakpoint_print_checkpoints(); }
    break;

  case 104:
#line 411 "mon_parse.y"
    {
                      mon_breakpoint_add_checkpoint((yyvsp[(2) - (3)].range)[0], (yyvsp[(2) - (3)].range)[1], TRUE, e_exec, TRUE, TRUE);
                  }
    break;

  case 105:
#line 415 "mon_parse.y"
    { mon_breakpoint_print_checkpoints(); }
    break;

  case 106:
#line 418 "mon_parse.y"
    {
                      if ((yyvsp[(2) - (5)].i)) {
                          temp = mon_breakpoint_add_checkpoint((yyvsp[(3) - (5)].range)[0], (yyvsp[(3) - (5)].range)[1], TRUE, (yyvsp[(2) - (5)].i), FALSE, TRUE);
                      } else {
                          temp = mon_breakpoint_add_checkpoint((yyvsp[(3) - (5)].range)[0], (yyvsp[(3) - (5)].range)[1], TRUE, e_load | e_store, FALSE, TRUE);
                      }
                      mon_breakpoint_set_checkpoint_condition(temp, (yyvsp[(4) - (5)].cond_node));
                  }
    break;

  case 107:
#line 427 "mon_parse.y"
    { mon_breakpoint_print_checkpoints(); }
    break;

  case 108:
#line 430 "mon_parse.y"
    {
                      if ((yyvsp[(2) - (5)].i)) {
                          temp = mon_breakpoint_add_checkpoint((yyvsp[(3) - (5)].range)[0], (yyvsp[(3) - (5)].range)[1], FALSE, (yyvsp[(2) - (5)].i), FALSE, TRUE);
                      } else {
                          temp = mon_breakpoint_add_checkpoint((yyvsp[(3) - (5)].range)[0], (yyvsp[(3) - (5)].range)[1], FALSE, e_exec | e_load | e_store, FALSE, TRUE);
                      }
                      mon_breakpoint_set_checkpoint_condition(temp, (yyvsp[(4) - (5)].cond_node));
                  }
    break;

  case 109:
#line 439 "mon_parse.y"
    { mon_breakpoint_print_checkpoints(); }
    break;

  case 110:
#line 444 "mon_parse.y"
    { mon_breakpoint_switch_checkpoint(e_ON, (yyvsp[(2) - (3)].i)); }
    break;

  case 111:
#line 446 "mon_parse.y"
    { mon_breakpoint_switch_checkpoint(e_ON, -1); }
    break;

  case 112:
#line 448 "mon_parse.y"
    { mon_breakpoint_switch_checkpoint(e_OFF, (yyvsp[(2) - (3)].i)); }
    break;

  case 113:
#line 450 "mon_parse.y"
    { mon_breakpoint_switch_checkpoint(e_OFF, -1); }
    break;

  case 114:
#line 452 "mon_parse.y"
    { mon_breakpoint_set_ignore_count((yyvsp[(2) - (3)].i), -1); }
    break;

  case 115:
#line 454 "mon_parse.y"
    { mon_breakpoint_set_ignore_count((yyvsp[(2) - (5)].i), (yyvsp[(4) - (5)].i)); }
    break;

  case 116:
#line 456 "mon_parse.y"
    { mon_breakpoint_delete_checkpoint((yyvsp[(2) - (3)].i)); }
    break;

  case 117:
#line 458 "mon_parse.y"
    { mon_breakpoint_delete_checkpoint(-1); }
    break;

  case 118:
#line 460 "mon_parse.y"
    { mon_breakpoint_set_checkpoint_condition((yyvsp[(2) - (5)].i), (yyvsp[(4) - (5)].cond_node)); }
    break;

  case 119:
#line 462 "mon_parse.y"
    { mon_breakpoint_set_checkpoint_command((yyvsp[(2) - (5)].i), (yyvsp[(4) - (5)].str)); }
    break;

  case 120:
#line 464 "mon_parse.y"
    { return ERR_EXPECT_STRING; }
    break;

  case 121:
#line 468 "mon_parse.y"
    { sidefx = (((yyvsp[(2) - (3)].action) == e_TOGGLE) ? (sidefx ^ 1) : (yyvsp[(2) - (3)].action)); }
    break;

  case 122:
#line 470 "mon_parse.y"
    {
                         mon_out("I/O side effects are %s\n",
                                   sidefx ? "enabled" : "disabled");
                     }
    break;

  case 123:
#line 475 "mon_parse.y"
    { 
                         break_on_dummy_access = (((yyvsp[(2) - (3)].action) == e_TOGGLE) ? (break_on_dummy_access ^ 1) : (yyvsp[(2) - (3)].action)); 
                         /* FIXME: some day we might want to toggle the break-on-dummy-access 
                                   per MEMSPACE, for now its a global option */                         
                         mon_breakpoint_set_dummy_state(e_default_space, break_on_dummy_access);
                     }
    break;

  case 124:
#line 482 "mon_parse.y"
    {
                         mon_out("Checkpoints will %strigger on dummy accesses.\n",
                                   break_on_dummy_access ? "" : "not ");
                         /* FIXME: some day we might want to toggle the break-on-dummy-access 
                                   per MEMSPACE, for now its a global option */                         
                         mon_breakpoint_set_dummy_state(e_default_space, break_on_dummy_access);
                     }
    break;

  case 125:
#line 490 "mon_parse.y"
    { 
                        int logenabled;
                        resources_get_int("MonitorLogEnabled", &logenabled);
                        logenabled = (((yyvsp[(2) - (3)].action) == e_TOGGLE) ? (logenabled ^ 1) : (yyvsp[(2) - (3)].action));
                        resources_set_int("MonitorLogEnabled", logenabled);
                     }
    break;

  case 126:
#line 497 "mon_parse.y"
    {
                         int logenabled;
                         const char *logfilename;
                         resources_get_int("MonitorLogEnabled", &logenabled);
                         resources_get_string("MonitorLogFileName", &logfilename);
                         if (logenabled) {
                            mon_out("Logging to '%s' is enabled.\n", logfilename);
                         } else {
                            mon_out("Logging is disabled.\n");
                         }
                     }
    break;

  case 127:
#line 509 "mon_parse.y"
    { 
                        resources_set_string("MonitorLogFileName", (yyvsp[(2) - (3)].str));
                     }
    break;

  case 128:
#line 513 "mon_parse.y"
    { default_radix = (yyvsp[(2) - (3)].rt); }
    break;

  case 129:
#line 515 "mon_parse.y"
    {
                         const char *p;

                         if (default_radix == e_hexadecimal)
                             p = "Hexadecimal";
                         else if (default_radix == e_decimal)
                             p = "Decimal";
                         else if (default_radix == e_octal)
                             p = "Octal";
                         else if (default_radix == e_binary)
                             p = "Binary";
                         else
                             p = "Unknown";

                         mon_out("Default radix is %s\n", p);
                     }
    break;

  case 130:
#line 533 "mon_parse.y"
    { monitor_change_device(e_default_space); }
    break;

  case 131:
#line 535 "mon_parse.y"
    { monitor_change_device((yyvsp[(2) - (3)].i)); }
    break;

  case 132:
#line 537 "mon_parse.y"
    { mon_export(); }
    break;

  case 133:
#line 539 "mon_parse.y"
    { mon_quit(); YYACCEPT; }
    break;

  case 134:
#line 541 "mon_parse.y"
    { mon_exit(); YYACCEPT; }
    break;

  case 135:
#line 543 "mon_parse.y"
    { mon_maincpu_trace(); }
    break;

  case 136:
#line 545 "mon_parse.y"
    { mon_maincpu_toggle_trace((yyvsp[(2) - (3)].action)); }
    break;

  case 137:
#line 549 "mon_parse.y"
    { mon_drive_execute_disk_cmd((yyvsp[(2) - (3)].str)); }
    break;

  case 138:
#line 551 "mon_parse.y"
    { mon_out("\t%d\n",(yyvsp[(2) - (3)].i)); }
    break;

  case 139:
#line 553 "mon_parse.y"
    { mon_command_print_help(NULL); }
    break;

  case 140:
#line 555 "mon_parse.y"
    { mon_command_print_help((yyvsp[(2) - (3)].str)); }
    break;

  case 141:
#line 557 "mon_parse.y"
    { mon_print_convert((yyvsp[(2) - (3)].i)); }
    break;

  case 142:
#line 559 "mon_parse.y"
    { mon_change_dir((yyvsp[(2) - (3)].str)); }
    break;

  case 143:
#line 561 "mon_parse.y"
    { mon_keyboard_feed((yyvsp[(2) - (3)].str)); }
    break;

  case 144:
#line 563 "mon_parse.y"
    { mon_backtrace(); }
    break;

  case 145:
#line 565 "mon_parse.y"
    { mon_show_dir((yyvsp[(2) - (3)].str)); }
    break;

  case 146:
#line 567 "mon_parse.y"
    { mon_show_pwd(); }
    break;

  case 147:
#line 569 "mon_parse.y"
    { mon_make_dir((yyvsp[(2) - (3)].str)); }
    break;

  case 148:
#line 571 "mon_parse.y"
    { mon_remove_dir((yyvsp[(2) - (3)].str)); }
    break;

  case 149:
#line 573 "mon_parse.y"
    { mon_screenshot_save((yyvsp[(2) - (3)].str),-1); }
    break;

  case 150:
#line 575 "mon_parse.y"
    { mon_screenshot_save((yyvsp[(2) - (5)].str),(yyvsp[(4) - (5)].i)); }
    break;

  case 151:
#line 577 "mon_parse.y"
    { mon_resource_get((yyvsp[(2) - (3)].str)); }
    break;

  case 152:
#line 579 "mon_parse.y"
    { mon_resource_set((yyvsp[(2) - (4)].str),(yyvsp[(3) - (4)].str)); }
    break;

  case 153:
#line 581 "mon_parse.y"
    { resources_load((yyvsp[(2) - (3)].str)); }
    break;

  case 154:
#line 583 "mon_parse.y"
    { resources_save((yyvsp[(2) - (3)].str)); }
    break;

  case 155:
#line 585 "mon_parse.y"
    { mon_reset_machine(-1); }
    break;

  case 156:
#line 587 "mon_parse.y"
    { mon_reset_machine((yyvsp[(3) - (4)].i)); }
    break;

  case 157:
#line 589 "mon_parse.y"
    { mon_tape_ctrl(TAPEPORT_PORT_1, (yyvsp[(3) - (4)].i)); }
    break;

  case 158:
#line 591 "mon_parse.y"
    { mon_tape_offs(TAPEPORT_PORT_1, -1); }
    break;

  case 159:
#line 593 "mon_parse.y"
    { mon_tape_offs(TAPEPORT_PORT_1, (yyvsp[(3) - (4)].i)); }
    break;

  case 160:
#line 595 "mon_parse.y"
    { mon_cart_freeze(); }
    break;

  case 161:
#line 597 "mon_parse.y"
    { mon_userport_set_output((yyvsp[(2) - (3)].i)); }
    break;

  case 162:
#line 599 "mon_parse.y"
    { mon_userport_get_output(); }
    break;

  case 163:
#line 601 "mon_parse.y"
    { mon_joyport_set_output((yyvsp[(2) - (4)].i), (yyvsp[(3) - (4)].i)); }
    break;

  case 164:
#line 603 "mon_parse.y"
    { mon_joyport_get_output((yyvsp[(2) - (3)].i)); }
    break;

  case 165:
#line 605 "mon_parse.y"
    { }
    break;

  case 166:
#line 607 "mon_parse.y"
    { mon_stopwatch_reset(); }
    break;

  case 167:
#line 609 "mon_parse.y"
    { mon_stopwatch_show(default_memspace, "Stopwatch: ", "\n"); }
    break;

  case 168:
#line 611 "mon_parse.y"
    { mon_profile_action((yyvsp[(2) - (3)].action)); }
    break;

  case 169:
#line 613 "mon_parse.y"
    { mon_profile(); }
    break;

  case 170:
#line 615 "mon_parse.y"
    { mon_profile_flat((yyvsp[(3) - (4)].i)); }
    break;

  case 171:
#line 617 "mon_parse.y"
    { mon_profile_graph((yyvsp[(3) - (4)].i), -1); }
    break;

  case 172:
#line 619 "mon_parse.y"
    { mon_profile_graph((yyvsp[(3) - (6)].i), (yyvsp[(5) - (6)].i)); }
    break;

  case 173:
#line 621 "mon_parse.y"
    { mon_profile_func((yyvsp[(3) - (4)].a)); }
    break;

  case 174:
#line 623 "mon_parse.y"
    { mon_profile_disass((yyvsp[(3) - (4)].a)); }
    break;

  case 175:
#line 625 "mon_parse.y"
    { mon_profile_clear((yyvsp[(3) - (4)].a)); }
    break;

  case 176:
#line 627 "mon_parse.y"
    { mon_profile_disass_context((yyvsp[(3) - (4)].i)); }
    break;

  case 177:
#line 631 "mon_parse.y"
    { mon_file_load((yyvsp[(2) - (5)].str), (yyvsp[(3) - (5)].i), (yyvsp[(4) - (5)].a), FALSE, FALSE); }
    break;

  case 178:
#line 633 "mon_parse.y"
    { mon_file_load((yyvsp[(2) - (5)].str), (yyvsp[(3) - (5)].i), (yyvsp[(4) - (5)].a), FALSE, TRUE); }
    break;

  case 179:
#line 635 "mon_parse.y"
    { mon_file_load((yyvsp[(2) - (5)].str), (yyvsp[(3) - (5)].i), (yyvsp[(4) - (5)].a), TRUE, FALSE); }
    break;

  case 180:
#line 637 "mon_parse.y"
    { return ERR_EXPECT_ADDRESS; }
    break;

  case 181:
#line 639 "mon_parse.y"
    { mon_file_save((yyvsp[(2) - (5)].str), (yyvsp[(3) - (5)].i), (yyvsp[(4) - (5)].range)[0], (yyvsp[(4) - (5)].range)[1], FALSE); }
    break;

  case 182:
#line 641 "mon_parse.y"
    { return ERR_EXPECT_DEVICE_NUM; }
    break;

  case 183:
#line 643 "mon_parse.y"
    { return ERR_EXPECT_ADDRESS; }
    break;

  case 184:
#line 645 "mon_parse.y"
    { mon_file_save((yyvsp[(2) - (5)].str), (yyvsp[(3) - (5)].i), (yyvsp[(4) - (5)].range)[0], (yyvsp[(4) - (5)].range)[1], TRUE); }
    break;

  case 185:
#line 647 "mon_parse.y"
    { return ERR_EXPECT_ADDRESS; }
    break;

  case 186:
#line 649 "mon_parse.y"
    { mon_file_verify((yyvsp[(2) - (5)].str),(yyvsp[(3) - (5)].i),(yyvsp[(4) - (5)].a),FALSE); }
    break;

  case 187:
#line 651 "mon_parse.y"
    { mon_file_verify((yyvsp[(2) - (5)].str),(yyvsp[(3) - (5)].i),(yyvsp[(4) - (5)].a),TRUE); }
    break;

  case 188:
#line 653 "mon_parse.y"
    { return ERR_EXPECT_ADDRESS; }
    break;

  case 189:
#line 655 "mon_parse.y"
    { mon_drive_block_cmd(0,(yyvsp[(2) - (5)].i),(yyvsp[(3) - (5)].i),(yyvsp[(4) - (5)].a)); }
    break;

  case 190:
#line 657 "mon_parse.y"
    { mon_drive_block_cmd(1,(yyvsp[(2) - (5)].i),(yyvsp[(3) - (5)].i),(yyvsp[(4) - (5)].a)); }
    break;

  case 191:
#line 659 "mon_parse.y"
    { mon_drive_list(-1); }
    break;

  case 192:
#line 661 "mon_parse.y"
    { mon_drive_list((yyvsp[(2) - (3)].i)); }
    break;

  case 193:
#line 663 "mon_parse.y"
    { mon_attach((yyvsp[(2) - (4)].str),(yyvsp[(3) - (4)].i)); }
    break;

  case 194:
#line 665 "mon_parse.y"
    { mon_detach((yyvsp[(2) - (3)].i)); }
    break;

  case 195:
#line 667 "mon_parse.y"
    { mon_autostart((yyvsp[(2) - (3)].str),0,1); }
    break;

  case 196:
#line 669 "mon_parse.y"
    { mon_autostart((yyvsp[(2) - (5)].str),(yyvsp[(4) - (5)].i),1); }
    break;

  case 197:
#line 671 "mon_parse.y"
    { mon_autostart((yyvsp[(2) - (3)].str),0,0); }
    break;

  case 198:
#line 673 "mon_parse.y"
    { mon_autostart((yyvsp[(2) - (5)].str),(yyvsp[(4) - (5)].i),0); }
    break;

  case 199:
#line 677 "mon_parse.y"
    { mon_record_commands((yyvsp[(2) - (3)].str)); }
    break;

  case 200:
#line 679 "mon_parse.y"
    { mon_end_recording(); }
    break;

  case 201:
#line 681 "mon_parse.y"
    { mon_playback_commands((yyvsp[(2) - (3)].str),true); }
    break;

  case 202:
#line 685 "mon_parse.y"
    { mon_memory_fill((yyvsp[(2) - (4)].a), BAD_ADDR, (unsigned char *)(yyvsp[(3) - (4)].str)); }
    break;

  case 203:
#line 687 "mon_parse.y"
    { printf("Not yet.\n"); }
    break;

  case 204:
#line 691 "mon_parse.y"
    {
#if YYDEBUG
                     yydebug = 1;
#endif
                     }
    break;

  case 205:
#line 698 "mon_parse.y"
    { (yyval.str) = (yyvsp[(1) - (1)].str); }
    break;

  case 206:
#line 701 "mon_parse.y"
    { (yyval.str) = (yyvsp[(1) - (1)].str); }
    break;

  case 207:
#line 702 "mon_parse.y"
    { (yyval.str) = NULL; }
    break;

  case 208:
#line 705 "mon_parse.y"
    { (yyval.str) = (yyvsp[(1) - (1)].str); }
    break;

  case 210:
#line 709 "mon_parse.y"
    { return ERR_EXPECT_FILENAME; }
    break;

  case 212:
#line 713 "mon_parse.y"
    { return ERR_EXPECT_DEVICE_NUM; }
    break;

  case 213:
#line 716 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (2)].i) | (yyvsp[(2) - (2)].i); }
    break;

  case 214:
#line 717 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (1)].i); }
    break;

  case 215:
#line 720 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (1)].i); }
    break;

  case 216:
#line 721 "mon_parse.y"
    { (yyval.i) = 0; }
    break;

  case 217:
#line 724 "mon_parse.y"
    {
                                    if (!mon_register_valid(default_memspace, (yyvsp[(1) - (1)].reg))) {
                                        return ERR_INVALID_REGISTER;
                                    }
                                    (yyval.i) = new_reg(default_memspace, (yyvsp[(1) - (1)].reg));
                                }
    break;

  case 218:
#line 730 "mon_parse.y"
    {
                                    if (!mon_register_valid((yyvsp[(1) - (2)].i), (yyvsp[(2) - (2)].reg))) {
                                        return ERR_INVALID_REGISTER;
                                    }
                                    (yyval.i) = new_reg((yyvsp[(1) - (2)].i), (yyvsp[(2) - (2)].reg));
                                }
    break;

  case 221:
#line 743 "mon_parse.y"
    { (monitor_cpu_for_memspace[reg_memspace((yyvsp[(1) - (3)].i))]->mon_register_set_val)(reg_memspace((yyvsp[(1) - (3)].i)), reg_regid((yyvsp[(1) - (3)].i)), (uint16_t) (yyvsp[(3) - (3)].i)); }
    break;

  case 222:
#line 746 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (1)].i); }
    break;

  case 223:
#line 747 "mon_parse.y"
    { return ERR_EXPECT_CHECKNUM; }
    break;

  case 224:
#line 750 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (1)].i); }
    break;

  case 225:
#line 751 "mon_parse.y"
    { (yyval.i) = -1; }
    break;

  case 227:
#line 755 "mon_parse.y"
    { (yyval.range)[0] = (yyvsp[(1) - (1)].a); (yyval.range)[1] = BAD_ADDR; }
    break;

  case 228:
#line 758 "mon_parse.y"
    { (yyval.range)[0] = (yyvsp[(1) - (3)].a); (yyval.range)[1] = (yyvsp[(3) - (3)].a); }
    break;

  case 229:
#line 760 "mon_parse.y"
    { if (resolve_range(e_default_space, (yyval.range), (yyvsp[(1) - (1)].str))) return ERR_ADDR_TOO_BIG; }
    break;

  case 230:
#line 762 "mon_parse.y"
    { if (resolve_range((yyvsp[(1) - (3)].i), (yyval.range), (yyvsp[(3) - (3)].str))) return ERR_ADDR_TOO_BIG; }
    break;

  case 231:
#line 765 "mon_parse.y"
    { (yyval.a) = (yyvsp[(2) - (2)].a); }
    break;

  case 232:
#line 766 "mon_parse.y"
    { (yyval.a) = BAD_ADDR; }
    break;

  case 233:
#line 770 "mon_parse.y"
    {
             (yyval.a) = new_addr(e_default_space,(yyvsp[(1) - (1)].i));
             if (opt_asm) new_cmd = asm_mode = 1;
         }
    break;

  case 234:
#line 775 "mon_parse.y"
    {
             (yyval.a) = new_addr((yyvsp[(1) - (3)].i), (yyvsp[(3) - (3)].i));
             if (opt_asm) new_cmd = asm_mode = 1;
         }
    break;

  case 235:
#line 780 "mon_parse.y"
    {
             temp = mon_symbol_table_lookup_addr(e_default_space, (yyvsp[(1) - (1)].str));
             if (temp >= 0)
                 (yyval.a) = new_addr(e_default_space, temp);
             else
                 return ERR_UNDEFINED_LABEL;
         }
    break;

  case 238:
#line 793 "mon_parse.y"
    { (yyval.i) = e_comp_space; }
    break;

  case 239:
#line 794 "mon_parse.y"
    { (yyval.i) = e_disk8_space; }
    break;

  case 240:
#line 795 "mon_parse.y"
    { (yyval.i) = e_disk9_space; }
    break;

  case 241:
#line 796 "mon_parse.y"
    { (yyval.i) = e_disk10_space; }
    break;

  case 242:
#line 797 "mon_parse.y"
    { (yyval.i) = e_disk11_space; }
    break;

  case 243:
#line 800 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (1)].i); if (!CHECK_ADDR((yyvsp[(1) - (1)].i))) return ERR_ADDR_TOO_BIG; }
    break;

  case 244:
#line 802 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (1)].i); }
    break;

  case 245:
#line 827 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (3)].i) + (yyvsp[(3) - (3)].i); }
    break;

  case 246:
#line 828 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (3)].i) - (yyvsp[(3) - (3)].i); }
    break;

  case 247:
#line 829 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (3)].i) * (yyvsp[(3) - (3)].i); }
    break;

  case 248:
#line 830 "mon_parse.y"
    { (yyval.i) = ((yyvsp[(3) - (3)].i)) ? ((yyvsp[(1) - (3)].i) / (yyvsp[(3) - (3)].i)) : 1; }
    break;

  case 249:
#line 831 "mon_parse.y"
    { (yyval.i) = (yyvsp[(2) - (3)].i); }
    break;

  case 250:
#line 832 "mon_parse.y"
    { return ERR_MISSING_CLOSE_PAREN; }
    break;

  case 251:
#line 833 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (1)].i); }
    break;

  case 252:
#line 836 "mon_parse.y"
    { (yyval.cond_node) = (yyvsp[(2) - (2)].cond_node); }
    break;

  case 253:
#line 837 "mon_parse.y"
    { (yyval.cond_node) = 0; }
    break;

  case 254:
#line 840 "mon_parse.y"
    {
               (yyval.cond_node) = new_cond; (yyval.cond_node)->is_parenthized = FALSE;
               (yyval.cond_node)->child1 = (yyvsp[(1) - (3)].cond_node); (yyval.cond_node)->child2 = (yyvsp[(3) - (3)].cond_node); (yyval.cond_node)->operation = (yyvsp[(2) - (3)].cond_op);
           }
    break;

  case 255:
#line 845 "mon_parse.y"
    { return ERR_INCOMPLETE_COND_OP; }
    break;

  case 256:
#line 847 "mon_parse.y"
    { (yyval.cond_node) = (yyvsp[(2) - (3)].cond_node); (yyval.cond_node)->is_parenthized = TRUE; }
    break;

  case 257:
#line 849 "mon_parse.y"
    { return ERR_MISSING_CLOSE_PAREN; }
    break;

  case 258:
#line 851 "mon_parse.y"
    { (yyval.cond_node) = (yyvsp[(1) - (1)].cond_node); }
    break;

  case 259:
#line 854 "mon_parse.y"
    { (yyval.cond_node) = new_cond;
                            (yyval.cond_node)->operation = e_INV;
                            (yyval.cond_node)->is_parenthized = FALSE;
                            (yyval.cond_node)->reg_num = (yyvsp[(1) - (1)].i); (yyval.cond_node)->is_reg = TRUE; (yyval.cond_node)->banknum=-1;
                            (yyval.cond_node)->child1 = NULL; (yyval.cond_node)->child2 = NULL;
                          }
    break;

  case 260:
#line 860 "mon_parse.y"
    { (yyval.cond_node) = new_cond;
                            (yyval.cond_node)->operation = e_INV;
                            (yyval.cond_node)->is_parenthized = FALSE;
                            (yyval.cond_node)->value = (yyvsp[(1) - (1)].i); (yyval.cond_node)->is_reg = FALSE; (yyval.cond_node)->banknum=-1;
                            (yyval.cond_node)->child1 = NULL; (yyval.cond_node)->child2 = NULL;
                          }
    break;

  case 261:
#line 867 "mon_parse.y"
    {
                            (yyval.cond_node) = new_cond;
                            (yyval.cond_node)->operation = e_INV;
                            (yyval.cond_node)->is_parenthized = FALSE;
                            (yyval.cond_node)->banknum = mon_banknum_from_bank(e_default_space, (yyvsp[(2) - (6)].str));
                            if ((yyval.cond_node)->banknum < 0) {
                                return ERR_ILLEGAL_INPUT;
                            }
                            (yyval.cond_node)->value = 0;
                            (yyval.cond_node)->is_reg = FALSE;
                            (yyval.cond_node)->child1 = (yyvsp[(5) - (6)].cond_node);
                            (yyval.cond_node)->child2 = NULL;
                        }
    break;

  case 262:
#line 880 "mon_parse.y"
    {
                            (yyval.cond_node) = new_cond;
                            (yyval.cond_node)->operation = e_INV;
                            (yyval.cond_node)->is_parenthized = FALSE;
                            (yyval.cond_node)->banknum = mon_banknum_from_bank(e_default_space, (yyvsp[(2) - (4)].str));
                            if ((yyval.cond_node)->banknum < 0) {
                                return ERR_ILLEGAL_INPUT;
                            }
                            (yyval.cond_node)->value = (yyvsp[(4) - (4)].a);
                            (yyval.cond_node)->is_reg = FALSE;
                            (yyval.cond_node)->child1 = NULL; (yyval.cond_node)->child2 = NULL;  
                        }
    break;

  case 265:
#line 898 "mon_parse.y"
    { mon_add_number_to_buffer((yyvsp[(1) - (1)].i)); }
    break;

  case 266:
#line 899 "mon_parse.y"
    { mon_add_string_to_buffer((yyvsp[(1) - (1)].str)); }
    break;

  case 269:
#line 906 "mon_parse.y"
    { mon_add_number_to_buffer((yyvsp[(1) - (1)].i)); }
    break;

  case 270:
#line 907 "mon_parse.y"
    { mon_add_number_masked_to_buffer((yyvsp[(1) - (1)].i), 0x00); }
    break;

  case 271:
#line 908 "mon_parse.y"
    { mon_add_string_to_buffer((yyvsp[(1) - (1)].str)); }
    break;

  case 272:
#line 911 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (1)].i); }
    break;

  case 273:
#line 912 "mon_parse.y"
    { (yyval.i) = (monitor_cpu_for_memspace[reg_memspace((yyvsp[(1) - (1)].i))]->mon_register_get_val)(reg_memspace((yyvsp[(1) - (1)].i)), reg_regid((yyvsp[(1) - (1)].i))); }
    break;

  case 274:
#line 915 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (1)].i); }
    break;

  case 275:
#line 916 "mon_parse.y"
    { (yyval.i) = (int)strtol((yyvsp[(1) - (1)].str), NULL, 10); }
    break;

  case 276:
#line 917 "mon_parse.y"
    { (yyval.i) = (int)strtol((yyvsp[(1) - (1)].str), NULL, 10); }
    break;

  case 277:
#line 918 "mon_parse.y"
    { (yyval.i) = (int)strtol((yyvsp[(1) - (1)].str), NULL, 10); }
    break;

  case 278:
#line 921 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (1)].i); }
    break;

  case 279:
#line 922 "mon_parse.y"
    { (yyval.i) = -1; }
    break;

  case 280:
#line 925 "mon_parse.y"
    { (yyval.i) = resolve_datatype(B_NUMBER,(yyvsp[(1) - (1)].str)); }
    break;

  case 281:
#line 926 "mon_parse.y"
    { (yyval.i) = resolve_datatype(D_NUMBER,(yyvsp[(1) - (1)].str)); }
    break;

  case 282:
#line 927 "mon_parse.y"
    { (yyval.i) = resolve_datatype(O_NUMBER,(yyvsp[(1) - (1)].str)); }
    break;

  case 283:
#line 930 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (1)].i); }
    break;

  case 284:
#line 931 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (1)].i); }
    break;

  case 285:
#line 932 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (1)].i); }
    break;

  case 286:
#line 933 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (1)].i); }
    break;

  case 287:
#line 934 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (1)].i); }
    break;

  case 291:
#line 942 "mon_parse.y"
    { (yyval.i) = 0;
                                                if ((yyvsp[(1) - (2)].str)) {
                                                    (monitor_cpu_for_memspace[default_memspace]->mon_assemble_instr)((yyvsp[(1) - (2)].str), (yyvsp[(2) - (2)].mode));
                                                } else {
                                                    new_cmd = 1;
                                                    asm_mode = 0;
                                                }
                                                opt_asm = 0;
                                              }
    break;

  case 293:
#line 953 "mon_parse.y"
    { asm_mode = 0; }
    break;

  case 294:
#line 956 "mon_parse.y"
    { if ((yyvsp[(2) - (2)].i) > 0xff) {
                          (yyval.mode).addr_mode = ASM_ADDR_MODE_IMMEDIATE_16;
                          (yyval.mode).param = (yyvsp[(2) - (2)].i);
                        } else {
                          (yyval.mode).addr_mode = ASM_ADDR_MODE_IMMEDIATE;
                          (yyval.mode).param = (yyvsp[(2) - (2)].i);
                        } }
    break;

  case 295:
#line 963 "mon_parse.y"
    { if ((yyvsp[(1) - (1)].i) >= 0x10000) {
               (yyval.mode).addr_mode = ASM_ADDR_MODE_ABSOLUTE_LONG;
               (yyval.mode).param = (yyvsp[(1) - (1)].i);
             } else if ((yyvsp[(1) - (1)].i) < 0x100) {
               (yyval.mode).addr_mode = ASM_ADDR_MODE_ZERO_PAGE;
               (yyval.mode).param = (yyvsp[(1) - (1)].i);
             } else {
               (yyval.mode).addr_mode = ASM_ADDR_MODE_ABSOLUTE;
               (yyval.mode).param = (yyvsp[(1) - (1)].i);
             }
           }
    break;

  case 296:
#line 974 "mon_parse.y"
    { if ((yyvsp[(1) - (3)].i) >= 0x10000) {
                            (yyval.mode).addr_mode = ASM_ADDR_MODE_ABSOLUTE_LONG_X;
                            (yyval.mode).param = (yyvsp[(1) - (3)].i);
                          } else if ((yyvsp[(1) - (3)].i) < 0x100) { 
                            (yyval.mode).addr_mode = ASM_ADDR_MODE_ZERO_PAGE_X;
                            (yyval.mode).param = (yyvsp[(1) - (3)].i);
                          } else {
                            (yyval.mode).addr_mode = ASM_ADDR_MODE_ABSOLUTE_X;
                            (yyval.mode).param = (yyvsp[(1) - (3)].i);
                          }
                        }
    break;

  case 297:
#line 985 "mon_parse.y"
    { if ((yyvsp[(1) - (3)].i) < 0x100) {
                            (yyval.mode).addr_mode = ASM_ADDR_MODE_ZERO_PAGE_Y;
                            (yyval.mode).param = (yyvsp[(1) - (3)].i);
                          } else {
                            (yyval.mode).addr_mode = ASM_ADDR_MODE_ABSOLUTE_Y;
                            (yyval.mode).param = (yyvsp[(1) - (3)].i);
                          }
                        }
    break;

  case 298:
#line 993 "mon_parse.y"
    { if ((yyvsp[(1) - (3)].i) < 0x100) {
                            (yyval.mode).addr_mode = ASM_ADDR_MODE_STACK_RELATIVE;
                            (yyval.mode).param = (yyvsp[(1) - (3)].i);
                          } else { /* 6809 */
                            (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
                            if ((yyvsp[(1) - (3)].i) >= -16 && (yyvsp[(1) - (3)].i) < 16) {
                                (yyval.mode).addr_submode = (yyvsp[(3) - (3)].i) | ((yyvsp[(1) - (3)].i) & 0x1F);
                            } else if ((yyvsp[(1) - (3)].i) >= -128 && (yyvsp[(1) - (3)].i) < 128) {
                                (yyval.mode).addr_submode = 0x80 | (yyvsp[(3) - (3)].i) | ASM_ADDR_MODE_INDEXED_OFF8;
                                (yyval.mode).param = (yyvsp[(1) - (3)].i);
                            } else if ((yyvsp[(1) - (3)].i) >= -32768 && (yyvsp[(1) - (3)].i) < 32768) {
                                (yyval.mode).addr_submode = 0x80 | (yyvsp[(3) - (3)].i) | ASM_ADDR_MODE_INDEXED_OFF16;
                                (yyval.mode).param = (yyvsp[(1) - (3)].i);
                            } else {
                                (yyval.mode).addr_mode = ASM_ADDR_MODE_ILLEGAL;
                                mon_out("offset too large even for 16 bits (signed)\n");
                            }
                          }
                        }
    break;

  case 299:
#line 1012 "mon_parse.y"
    { if ((yyvsp[(1) - (3)].i) < 0x100) {
                            (yyval.mode).addr_mode = ASM_ADDR_MODE_DOUBLE;
                            (yyval.mode).param = (yyvsp[(3) - (3)].i);
                            (yyval.mode).addr_submode = (yyvsp[(1) - (3)].i);
                          }
                        }
    break;

  case 300:
#line 1018 "mon_parse.y"
    { if ((yyvsp[(2) - (3)].i) < 0x100) {
                               (yyval.mode).addr_mode = ASM_ADDR_MODE_INDIRECT;
                               (yyval.mode).param = (yyvsp[(2) - (3)].i);
                             } else {
                               (yyval.mode).addr_mode = ASM_ADDR_MODE_ABS_INDIRECT;
                               (yyval.mode).param = (yyvsp[(2) - (3)].i);
                             }
                           }
    break;

  case 301:
#line 1026 "mon_parse.y"
    { if ((yyvsp[(2) - (5)].i) < 0x100) {
                                           (yyval.mode).addr_mode = ASM_ADDR_MODE_INDIRECT_X;
                                           (yyval.mode).param = (yyvsp[(2) - (5)].i);
                                         } else {
                                           (yyval.mode).addr_mode = ASM_ADDR_MODE_ABS_INDIRECT_X;
                                           (yyval.mode).param = (yyvsp[(2) - (5)].i);
                                         }
                                       }
    break;

  case 302:
#line 1035 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_STACK_RELATIVE_Y; (yyval.mode).param = (yyvsp[(2) - (7)].i); }
    break;

  case 303:
#line 1037 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_INDIRECT_Y; (yyval.mode).param = (yyvsp[(2) - (5)].i); }
    break;

  case 304:
#line 1038 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_IND_BC; }
    break;

  case 305:
#line 1039 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_IND_DE; }
    break;

  case 306:
#line 1040 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_IND_HL; }
    break;

  case 307:
#line 1041 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_IND_IX; }
    break;

  case 308:
#line 1042 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_IND_IY; }
    break;

  case 309:
#line 1043 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_IND_SP; }
    break;

  case 310:
#line 1045 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_ABSOLUTE_A; (yyval.mode).param = (yyvsp[(2) - (5)].i); }
    break;

  case 311:
#line 1047 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_ABSOLUTE_HL; (yyval.mode).param = (yyvsp[(2) - (5)].i); }
    break;

  case 312:
#line 1049 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_ABSOLUTE_IX; (yyval.mode).param = (yyvsp[(2) - (5)].i); }
    break;

  case 313:
#line 1051 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_ABSOLUTE_IY; (yyval.mode).param = (yyvsp[(2) - (5)].i); }
    break;

  case 314:
#line 1052 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_IMPLIED; }
    break;

  case 315:
#line 1053 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_ACCUMULATOR; }
    break;

  case 316:
#line 1054 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_B; }
    break;

  case 317:
#line 1055 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_C; }
    break;

  case 318:
#line 1056 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_D; }
    break;

  case 319:
#line 1057 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_E; }
    break;

  case 320:
#line 1058 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_H; }
    break;

  case 321:
#line 1059 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_IXH; }
    break;

  case 322:
#line 1060 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_IYH; }
    break;

  case 323:
#line 1061 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_L; }
    break;

  case 324:
#line 1062 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_IXL; }
    break;

  case 325:
#line 1063 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_IYL; }
    break;

  case 326:
#line 1064 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_AF; }
    break;

  case 327:
#line 1065 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_BC; }
    break;

  case 328:
#line 1066 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_DE; }
    break;

  case 329:
#line 1067 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_HL; }
    break;

  case 330:
#line 1068 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_IX; }
    break;

  case 331:
#line 1069 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_IY; }
    break;

  case 332:
#line 1070 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_REG_SP; }
    break;

  case 333:
#line 1072 "mon_parse.y"
    { (yyval.mode).addr_mode = ASM_ADDR_MODE_DIRECT; (yyval.mode).param = (yyvsp[(2) - (2)].i); }
    break;

  case 334:
#line 1073 "mon_parse.y"
    {    /* Clash with addr,x addr,y addr,s modes! */
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        if ((yyvsp[(1) - (3)].i) >= -16 && (yyvsp[(1) - (3)].i) < 16) {
            (yyval.mode).addr_submode = (3 << 5) | ((yyvsp[(1) - (3)].i) & 0x1F);
        } else if ((yyvsp[(1) - (3)].i) >= -128 && (yyvsp[(1) - (3)].i) < 128) {
            (yyval.mode).addr_submode = 0x80 | (3 << 5) | ASM_ADDR_MODE_INDEXED_OFF8;
            (yyval.mode).param = (yyvsp[(1) - (3)].i);
        } else if ((yyvsp[(1) - (3)].i) >= -32768 && (yyvsp[(1) - (3)].i) < 32768) {
            (yyval.mode).addr_submode = 0x80 | (3 << 5) | ASM_ADDR_MODE_INDEXED_OFF16;
            (yyval.mode).param = (yyvsp[(1) - (3)].i);
        } else {
            (yyval.mode).addr_mode = ASM_ADDR_MODE_ILLEGAL;
            mon_out("offset too large even for 16 bits (signed)\n");
        }
    }
    break;

  case 335:
#line 1088 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | (yyvsp[(2) - (3)].i) | ASM_ADDR_MODE_INDEXED_INC1;
        }
    break;

  case 336:
#line 1092 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | (yyvsp[(2) - (4)].i) | ASM_ADDR_MODE_INDEXED_INC2;
        }
    break;

  case 337:
#line 1096 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | (yyvsp[(3) - (3)].i) | ASM_ADDR_MODE_INDEXED_DEC1;
        }
    break;

  case 338:
#line 1100 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | (yyvsp[(4) - (4)].i) | ASM_ADDR_MODE_INDEXED_DEC2;
        }
    break;

  case 339:
#line 1104 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | (yyvsp[(2) - (2)].i) | ASM_ADDR_MODE_INDEXED_OFF0;
        }
    break;

  case 340:
#line 1108 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | (yyvsp[(2) - (3)].i) | ASM_ADDR_MODE_INDEXED_OFFB;
        }
    break;

  case 341:
#line 1112 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | (yyvsp[(2) - (3)].i) | ASM_ADDR_MODE_INDEXED_OFFA;
        }
    break;

  case 342:
#line 1116 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | (yyvsp[(2) - (3)].i) | ASM_ADDR_MODE_INDEXED_OFFD;
        }
    break;

  case 343:
#line 1120 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).param = (yyvsp[(1) - (3)].i);
        if ((yyvsp[(1) - (3)].i) >= -128 && (yyvsp[(1) - (3)].i) < 128) {
            (yyval.mode).addr_submode = ASM_ADDR_MODE_INDEXED_OFFPC8;
        } else if ((yyvsp[(1) - (3)].i) >= -32768 && (yyvsp[(1) - (3)].i) < 32768) {
            (yyval.mode).addr_submode = ASM_ADDR_MODE_INDEXED_OFFPC16;
        } else {
            (yyval.mode).addr_mode = ASM_ADDR_MODE_ILLEGAL;
            mon_out("offset too large even for 16 bits (signed)\n");
        }
    }
    break;

  case 344:
#line 1132 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        if ((yyvsp[(2) - (5)].i) >= -16 && (yyvsp[(2) - (5)].i) < 16) {
            (yyval.mode).addr_submode = (yyvsp[(2) - (5)].i) & 0x1F;
        } else if ((yyvsp[(1) - (5)].i) >= -128 && (yyvsp[(1) - (5)].i) < 128) {
            (yyval.mode).addr_submode = ASM_ADDR_MODE_INDEXED_OFF8;
            (yyval.mode).param = (yyvsp[(2) - (5)].i);
        } else if ((yyvsp[(2) - (5)].i) >= -32768 && (yyvsp[(2) - (5)].i) < 32768) {
            (yyval.mode).addr_submode = ASM_ADDR_MODE_INDEXED_OFF16;
            (yyval.mode).param = (yyvsp[(2) - (5)].i);
        } else {
            (yyval.mode).addr_mode = ASM_ADDR_MODE_ILLEGAL;
            mon_out("offset too large even for 16 bits (signed)\n");
        }
    }
    break;

  case 345:
#line 1147 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | (yyvsp[(3) - (5)].i) | ASM_ADDR_MODE_INDEXED_INC1;
        }
    break;

  case 346:
#line 1151 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | (yyvsp[(3) - (6)].i) | ASM_ADDR_MODE_INDEXED_INC2;
        }
    break;

  case 347:
#line 1155 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | (yyvsp[(4) - (5)].i) | ASM_ADDR_MODE_INDEXED_DEC1;
        }
    break;

  case 348:
#line 1159 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | (yyvsp[(5) - (6)].i) | ASM_ADDR_MODE_INDEXED_DEC2;
        }
    break;

  case 349:
#line 1163 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | (yyvsp[(3) - (4)].i) | ASM_ADDR_MODE_INDEXED_OFF0;
        }
    break;

  case 350:
#line 1167 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | (yyvsp[(3) - (5)].i) | ASM_ADDR_MODE_INDEXED_OFFB;
        }
    break;

  case 351:
#line 1171 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | (yyvsp[(3) - (5)].i) | ASM_ADDR_MODE_INDEXED_OFFA;
        }
    break;

  case 352:
#line 1175 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | (yyvsp[(3) - (5)].i) | ASM_ADDR_MODE_INDEXED_OFFD;
        }
    break;

  case 353:
#line 1179 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).param = (yyvsp[(2) - (5)].i);
        if ((yyvsp[(2) - (5)].i) >= -128 && (yyvsp[(2) - (5)].i) < 128) {
            (yyval.mode).addr_submode = ASM_ADDR_MODE_INDEXED_OFFPC8_IND;
        } else if ((yyvsp[(2) - (5)].i) >= -32768 && (yyvsp[(2) - (5)].i) < 32768) {
            (yyval.mode).addr_submode = ASM_ADDR_MODE_INDEXED_OFFPC16_IND;
        } else {
            (yyval.mode).addr_mode = ASM_ADDR_MODE_ILLEGAL;
            mon_out("offset too large even for 16 bits (signed)\n");
        }
    }
    break;

  case 354:
#line 1191 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDEXED;
        (yyval.mode).addr_submode = 0x80 | ASM_ADDR_MODE_EXTENDED_INDIRECT;
        (yyval.mode).param = (yyvsp[(2) - (3)].i);
        }
    break;

  case 355:
#line 1196 "mon_parse.y"
    {
        (yyval.mode).addr_mode = ASM_ADDR_MODE_INDIRECT_LONG_Y;
        (yyval.mode).param = (yyvsp[(2) - (5)].i);
        }
    break;

  case 356:
#line 1204 "mon_parse.y"
    { (yyval.i) = (0 << 5); printf("reg_x\n"); }
    break;

  case 357:
#line 1205 "mon_parse.y"
    { (yyval.i) = (1 << 5); printf("reg_y\n"); }
    break;

  case 358:
#line 1206 "mon_parse.y"
    { (yyval.i) = (yyvsp[(1) - (1)].i); }
    break;

  case 359:
#line 1207 "mon_parse.y"
    { (yyval.i) = (3 << 5); printf("reg_s\n"); }
    break;

  case 360:
#line 1211 "mon_parse.y"
    { (yyval.i) = (2 << 5); printf("reg_u\n"); }
    break;


/* Line 1267 of yacc.c.  */
#line 4738 "mon_parse.c"
      default: break;
    }
  YY_SYMBOL_PRINT ("-> $$ =", yyr1[yyn], &yyval, &yyloc);

  YYPOPSTACK (yylen);
  yylen = 0;
  YY_STACK_PRINT (yyss, yyssp);

  *++yyvsp = yyval;


  /* Now `shift' the result of the reduction.  Determine what state
     that goes to, based on the state we popped back to and the rule
     number reduced by.  */

  yyn = yyr1[yyn];

  yystate = yypgoto[yyn - YYNTOKENS] + *yyssp;
  if (0 <= yystate && yystate <= YYLAST && yycheck[yystate] == *yyssp)
    yystate = yytable[yystate];
  else
    yystate = yydefgoto[yyn - YYNTOKENS];

  goto yynewstate;


/*------------------------------------.
| yyerrlab -- here on detecting error |
`------------------------------------*/
yyerrlab:
  /* If not already recovering from an error, report this error.  */
  if (!yyerrstatus)
    {
      ++yynerrs;
#if ! YYERROR_VERBOSE
      yyerror (YY_("syntax error"));
#else
      {
	YYSIZE_T yysize = yysyntax_error (0, yystate, yychar);
	if (yymsg_alloc < yysize && yymsg_alloc < YYSTACK_ALLOC_MAXIMUM)
	  {
	    YYSIZE_T yyalloc = 2 * yysize;
	    if (! (yysize <= yyalloc && yyalloc <= YYSTACK_ALLOC_MAXIMUM))
	      yyalloc = YYSTACK_ALLOC_MAXIMUM;
	    if (yymsg != yymsgbuf)
	      YYSTACK_FREE (yymsg);
	    yymsg = (char *) YYSTACK_ALLOC (yyalloc);
	    if (yymsg)
	      yymsg_alloc = yyalloc;
	    else
	      {
		yymsg = yymsgbuf;
		yymsg_alloc = sizeof yymsgbuf;
	      }
	  }

	if (0 < yysize && yysize <= yymsg_alloc)
	  {
	    (void) yysyntax_error (yymsg, yystate, yychar);
	    yyerror (yymsg);
	  }
	else
	  {
	    yyerror (YY_("syntax error"));
	    if (yysize != 0)
	      goto yyexhaustedlab;
	  }
      }
#endif
    }



  if (yyerrstatus == 3)
    {
      /* If just tried and failed to reuse look-ahead token after an
	 error, discard it.  */

      if (yychar <= YYEOF)
	{
	  /* Return failure if at end of input.  */
	  if (yychar == YYEOF)
	    YYABORT;
	}
      else
	{
	  yydestruct ("Error: discarding",
		      yytoken, &yylval);
	  yychar = YYEMPTY;
	}
    }

  /* Else will try to reuse look-ahead token after shifting the error
     token.  */
  goto yyerrlab1;


/*---------------------------------------------------.
| yyerrorlab -- error raised explicitly by YYERROR.  |
`---------------------------------------------------*/
yyerrorlab:

  /* Pacify compilers like GCC when the user code never invokes
     YYERROR and the label yyerrorlab therefore never appears in user
     code.  */
  if (/*CONSTCOND*/ 0)
     goto yyerrorlab;

  /* Do not reclaim the symbols of the rule which action triggered
     this YYERROR.  */
  YYPOPSTACK (yylen);
  yylen = 0;
  YY_STACK_PRINT (yyss, yyssp);
  yystate = *yyssp;
  goto yyerrlab1;


/*-------------------------------------------------------------.
| yyerrlab1 -- common code for both syntax error and YYERROR.  |
`-------------------------------------------------------------*/
yyerrlab1:
  yyerrstatus = 3;	/* Each real token shifted decrements this.  */

  for (;;)
    {
      yyn = yypact[yystate];
      if (yyn != YYPACT_NINF)
	{
	  yyn += YYTERROR;
	  if (0 <= yyn && yyn <= YYLAST && yycheck[yyn] == YYTERROR)
	    {
	      yyn = yytable[yyn];
	      if (0 < yyn)
		break;
	    }
	}

      /* Pop the current state because it cannot handle the error token.  */
      if (yyssp == yyss)
	YYABORT;


      yydestruct ("Error: popping",
		  yystos[yystate], yyvsp);
      YYPOPSTACK (1);
      yystate = *yyssp;
      YY_STACK_PRINT (yyss, yyssp);
    }

  if (yyn == YYFINAL)
    YYACCEPT;

  *++yyvsp = yylval;


  /* Shift the error token.  */
  YY_SYMBOL_PRINT ("Shifting", yystos[yyn], yyvsp, yylsp);

  yystate = yyn;
  goto yynewstate;


/*-------------------------------------.
| yyacceptlab -- YYACCEPT comes here.  |
`-------------------------------------*/
yyacceptlab:
  yyresult = 0;
  goto yyreturn;

/*-----------------------------------.
| yyabortlab -- YYABORT comes here.  |
`-----------------------------------*/
yyabortlab:
  yyresult = 1;
  goto yyreturn;

#ifndef yyoverflow
/*-------------------------------------------------.
| yyexhaustedlab -- memory exhaustion comes here.  |
`-------------------------------------------------*/
yyexhaustedlab:
  yyerror (YY_("memory exhausted"));
  yyresult = 2;
  /* Fall through.  */
#endif

yyreturn:
  if (yychar != YYEOF && yychar != YYEMPTY)
     yydestruct ("Cleanup: discarding lookahead",
		 yytoken, &yylval);
  /* Do not reclaim the symbols of the rule which action triggered
     this YYABORT or YYACCEPT.  */
  YYPOPSTACK (yylen);
  YY_STACK_PRINT (yyss, yyssp);
  while (yyssp != yyss)
    {
      yydestruct ("Cleanup: popping",
		  yystos[*yyssp], yyvsp);
      YYPOPSTACK (1);
    }
#ifndef yyoverflow
  if (yyss != yyssa)
    YYSTACK_FREE (yyss);
#endif
#if YYERROR_VERBOSE
  if (yymsg != yymsgbuf)
    YYSTACK_FREE (yymsg);
#endif
  /* Make sure YYID is used.  */
  return YYID (yyresult);
}


#line 1215 "mon_parse.y"


int parse_and_execute_line(char *input)
{
   char *temp_buf;
   int i, rc;

   if (default_memspace == e_comp_space) {
       /*
        * If the command is to be executed when the default address space is the main cpu,
        * Ensure drive CPU emulation is up to date with main cpu CLOCK.
        */
       /* FIXME: should this be drive_catch_up_hook() instead? */
       /*drive_cpu_execute_all(maincpu_clk);*/
       drive_catch_up_hook(maincpu_clk);
   }

   temp_buf = lib_malloc(strlen(input) + 3);
   strcpy(temp_buf,input);
   i = (int)strlen(input);
   temp_buf[i++] = '\n';
   temp_buf[i++] = '\0';
   temp_buf[i++] = '\0';

   make_buffer(temp_buf);
   mon_clear_buffer();
   if ( (rc =yyparse()) != 0) {
       mon_out("ERROR -- ");
       switch(rc) {
         case ERR_BAD_CMD:
           mon_out("Bad command:\n");
           break;
         case ERR_RANGE_BAD_START:
           mon_out("Bad first address in range:\n");
           break;
         case ERR_RANGE_BAD_END:
           mon_out("Bad second address in range:\n");
           break;
         case ERR_EXPECT_CHECKNUM:
           mon_out("Checkpoint number expected:\n");
           break;
         case ERR_EXPECT_END_CMD:
           mon_out("Unexpected token:\n");
           break;
         case ERR_MISSING_CLOSE_PAREN:
           mon_out("')' expected:\n");
           break;
         case ERR_INCOMPLETE_COND_OP:
           mon_out("Conditional operation missing an operand:\n");
           break;
         case ERR_EXPECT_FILENAME:
           mon_out("Expecting a filename:\n");
           break;
         case ERR_ADDR_TOO_BIG:
           mon_out("Address too large:\n");
           break;
         case ERR_IMM_TOO_BIG:
           mon_out("Immediate argument too large:\n");
           break;
         case ERR_EXPECT_STRING:
           mon_out("Expecting a string.\n");
           break;
         case ERR_UNDEFINED_LABEL:
           mon_out("Found an undefined label.\n");
           break;
         case ERR_EXPECT_DEVICE_NUM:
           mon_out("Expecting a device number.\n");
           break;
         case ERR_EXPECT_ADDRESS:
           mon_out("Expecting an address.\n");
           break;
         case ERR_INVALID_REGISTER:
           mon_out("Invalid register.\n");
           break;
         case ERR_ILLEGAL_INPUT:
         default:
           mon_out("Wrong syntax:\n");
       }
       mon_out("  %s\n", input);
       for (i = 0; i < last_len; i++)
           mon_out(" ");
       mon_out("  ^\n");
       asm_mode = 0;
       new_cmd = 1;
   }
   lib_free(temp_buf);
   free_buffer();

   return rc;
}

void set_yydebug(int val)
{
#if YYDEBUG
    yydebug = val;
#else
#endif
}

static int yyerror(char *s)
{
#if 0
   fprintf(stderr, "ERR:%s\n", s);
#endif
   return 0;
}

/* convert the string in "num" to a numeric value, depending on radix. this 
   function does some magic conversion on addresses when radix is not hex.
*/
static int resolve_datatype(unsigned guess_type, const char *num)
{
    int binary = 1, hex = 0, octal = 0, decimal = 1;
    const char *c;

    /* FIXME: Handle cases when default type is non-numerical */
    if (default_radix == e_hexadecimal) {
        return (int)strtol(num, NULL, 16);
    }

    /* we do some educated guessing on what type of number we have here */
    if (num[0] == '0') {
        /* might be octal with leading zero */
        octal = 1;
    }
    /* a string containing any digits not 0 or 1 can't be a binary number */
    c = num;
    while (*c) {
        if ((*c != '0') && (*c != '1')) {
            binary = 0;
            break;
        }
        c++;
    }
    /* a string containing 8 or 9 can't be an octal number */
    c = num;
    while (*c) {
        if ((*c == '8') && (*c == '9')) {
            octal = 0;
            break;
        }
        c++;
    }
    /* a string containing any of A-F can only be a hex number */
    c = num;
    while (*c) {
        if ((tolower((unsigned char)*c) >= 'a') && (tolower((unsigned char)*c) <= 'f')) {
            hex = 1;
            octal = 0;
            binary = 0;
            decimal = 0;
            break;
        }
        c++;
    }

    /* a hex number can only be hex no matter what */
    if (hex) {
        return (int)strtol(num, NULL, 16);
    }

    /* first, if default radix and detected number matches, just do it */
    if (binary && (default_radix == e_binary)) {
        return (int)strtol(num, NULL, 2);
    }
    if (decimal && (default_radix == e_decimal)) {
        return (int)strtol(num, NULL, 10);
    }
    if (octal && (default_radix == e_octal)) {
        return (int)strtol(num, NULL, 8);
    }

    /* second, if detected number matches guess type, do it */
    if (binary && (guess_type == B_NUMBER)) {
        return (int)strtol(num, NULL, 2);
    }
    if (decimal && (guess_type == D_NUMBER)) {
        return (int)strtol(num, NULL, 10);
    }
    if (octal && (guess_type == O_NUMBER)) {
        return (int)strtol(num, NULL, 8);
    }

    /* third only use the detected type */
    if (binary) {
        return (int)strtol(num, NULL, 2);
    }
    if (decimal) {
        return (int)strtol(num, NULL, 10);
    }
    if (octal) {
        return (int)strtol(num, NULL, 8);
    }

    /* use hex as default, should we ever come here */
    return (int)strtol(num, NULL, 16);
}

/*
 * Resolve a character sequence containing 8 hex digits like "08001000".
 * This could be a lazy version of "0800 1000". If the default radix is not
 * hexadecimal, we handle it like a ordinary number, in the latter case there
 * is only one number in the range.
 */
static int resolve_range(enum t_memspace memspace, MON_ADDR range[2],
                         const char *num)
{
    char start[5];
    char end[5];
    long sa;

    range[1] = BAD_ADDR;

    switch (default_radix)
    {
    case e_hexadecimal:
        /* checked twice, but as the code must have exactly 8 digits: */
        if (strlen(num) == 8) {
            memcpy(start, num, 4);
            start[4] = '\0';
            memcpy(end, num + 4, 4);
            end[4] = '\0';
            sa = strtol(start, NULL, 16);
            range[1] = (int)new_addr(memspace, strtol(end, NULL, 16));
        }
        else
            sa = strtol(num, NULL, 16);
        break;

    case e_decimal:
       sa = strtol(num, NULL, 10);
       break;

    case e_octal:
       sa = strtol(num, NULL, 8);
       break;

    default:
       sa = strtol(num, NULL, 2);
    }

    if (!CHECK_ADDR(sa))
        return ERR_ADDR_TOO_BIG;

    range[0] = (int)new_addr(memspace, sa);
    return 0;
}

