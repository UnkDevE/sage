# SYNOPSIS
#
#   SAGE_SPKG_COLLECT
#
# DESCRIPTION
#
#   This macro gathers up information about SPKGs defined in the build/pkgs
#   directory of the Sage source tree, and generates variables to be
#   substituted into the build/make/Makefile.in template which list all the
#   SPKGs, their versions, their dependencies, and categorizes them based
#   on how they should be installed.
#
#   In particular, this generates the Makefile variables:
#
#      - SAGE_BUILT_PACKAGES - lists the names of SPKGs that should be built
#        and installed from source.
#
#      - SAGE_DUMMY_PACKAGES - lists the names of packages that are not built
#        as part of Sage--either they are not required for the current
#        platform, or the dependency on them is satisfied by an existing
#        system package.
#
#      - SAGE_OPTIONAL_INSTALLED_PACKAGES - lists the names of packages with the
#        "standard", "optional", or "experimental" type that should be installed.
#
#      - SAGE_OPTIONAL_UNINSTALLED_PACKAGES - lists the names of packages with the
#        "standard", "optional", or "experimental" type that should be uninstalled.
#
#      - SAGE_SDIST_PACKAGES - lists the names of all packages whose sources
#        need to be downloaded to be included in the source distribution.
#
#      - SAGE_PACKAGE_VERSIONS - this template variable defines multiple
#        Makefile variables in the format "vers_<packagename>" the value
#        of which is the current version of the SPKG <packagename>.
#
#      - SAGE_PACKAGE_DEPENDENCIES - this template variable defines multiple
#        Makefile variables in the format "deps_<packagename>" the value
#        of which is the names of the dependencies of <packagename> as read
#        from the build/<packagename>/dependencies file.
#
#      - SAGE_NORMAL_PACKAGES - lists the names of packages that are installed
#        by the "normal" method (using the sage-spkg program to download and
#        extract the source tarball, and run the relevant scripts from
#        build/<packagename>/spkg-*.
#
#      - SAGE_PIP_PACKAGES - lists the names of packages with the "pip" type
#        which are installed by directly invoking the pip command.
#
#      - SAGE_SCRIPT_PACKAGES - lists the names of packages with the "script"
#        type which are installed by running a custom script, which may
#        download additional source files.
#

dnl ==========================================================================
dnl define PKG_CHECK_VAR for old pkg-config < 0.28; see Trac #29001
m4_ifndef([PKG_CHECK_VAR], [
AC_DEFUN([PKG_CHECK_VAR],
[AC_REQUIRE([PKG_PROG_PKG_CONFIG])dnl
AC_ARG_VAR([$1], [value of $3 for $2, overriding pkg-config])dnl

_PKG_CONFIG([$1], [variable="][$3]["], [$2])
AS_VAR_COPY([$1], [pkg_cv_][$1])

AS_VAR_IF([$1], [""], [$5], [$4])dnl
])dnl PKG_CHECK_VAR
])

dnl ==========================================================================
AC_DEFUN_ONCE([SAGE_SPKG_COLLECT], [
dnl The m4/sage_spkg_configures.m4 file is generated by bootstrap.
dnl It contains:
dnl - "m4_sinclude"s for the build/pkgs/SPKG/spkg-configure.m4 files
dnl - calls to SAGE_SPKG_CONFIGURE_* macros defined there
dnl - calls to SAGE_SPKG for all packages
dnl - calls to SAGE_SPKG_ENABLE for optional/experimental packages
m4_include([m4/sage_spkg_configures.m4])
])

dnl ==========================================================================
AC_DEFUN([SAGE_SPKG_COLLECT_INIT], [
dnl Intialize the collection variables.
# To deal with ABI incompatibilities when gcc is upgraded, every package
# (except gcc) should depend on gcc if gcc is already installed.
# See https://trac.sagemath.org/ticket/24703
if test x$SAGE_INSTALL_GCC = xexists; then
    SAGE_GCC_DEP='$(SAGE_LOCAL)/bin/gcc'
else
    SAGE_GCC_DEP=''
fi
AC_SUBST([SAGE_GCC_DEP])

AS_BOX([Build status for each package:                                         ]) >& AS_MESSAGE_FD
AS_BOX([Build status for each package:                                         ]) >& AS_MESSAGE_LOG_FD

# Usage: newest_version $pkg
# Print version number of latest package $pkg
newest_version() {
    SPKG=$[1]
    if test -f "$SAGE_ROOT/build/pkgs/$SPKG/package-version.txt" ; then
        cat "$SAGE_ROOT/build/pkgs/$SPKG/package-version.txt"
    else
        echo none
    fi
}

# Packages that are actually built/installed as opposed to packages that are
# not required on this platform or that can be taken from the underlying system
# installation. Note that this contains packages that are not actually going to
# be installed by most users because they are optional/experimental.
SAGE_BUILT_PACKAGES=''

# The complement of SAGE_BUILT_PACKAGES, i.e., packages that are not required
# on this platform or packages where we found a suitable package on the
# underlying system.
SAGE_DUMMY_PACKAGES=''

# List of currently installed and to-be-installed standard/optional/experimental packages
SAGE_OPTIONAL_INSTALLED_PACKAGES=''
# List of optional packages to be uninstalled
SAGE_OPTIONAL_UNINSTALLED_PACKAGES=''

# List of all packages that should be downloaded
SAGE_SDIST_PACKAGES=''

# Generate package version/dependency/tree lists
SAGE_PACKAGE_VERSIONS=""
SAGE_PACKAGE_DEPENDENCIES=""
SAGE_PACKAGE_TREES=""
# Lists of packages categorized according to their build rules
SAGE_NORMAL_PACKAGES=''
SAGE_PIP_PACKAGES=''
SAGE_SCRIPT_PACKAGES=''

SAGE_NEED_SYSTEM_PACKAGES=""
SAGE_NEED_SYSTEM_PACKAGES_OPTIONAL=""

AC_SUBST([SAGE_PACKAGE_VERSIONS])
AC_SUBST([SAGE_PACKAGE_DEPENDENCIES])
AC_SUBST([SAGE_PACKAGE_TREES])
AC_SUBST([SAGE_NORMAL_PACKAGES])
AC_SUBST([SAGE_PIP_PACKAGES])
AC_SUBST([SAGE_SCRIPT_PACKAGES])
AC_SUBST([SAGE_BUILT_PACKAGES])
AC_SUBST([SAGE_DUMMY_PACKAGES])
AC_SUBST([SAGE_OPTIONAL_INSTALLED_PACKAGES])
AC_SUBST([SAGE_OPTIONAL_UNINSTALLED_PACKAGES])
AC_SUBST([SAGE_SDIST_PACKAGES])
])


dnl ==========================================================================
AC_DEFUN([SAGE_SPKG_FINALIZE], [dnl
    AC_REQUIRE([SAGE_SPKG_COLLECT_INIT])dnl
    m4_pushdef([SPKG_NAME], [$1])dnl
    m4_pushdef([SPKG_TYPE], [$2])dnl
    m4_pushdef([SPKG_SOURCE], [$3])dnl
    dnl add SPKG_NAME to the SAGE_PACKAGE_VERSIONS and
    dnl SAGE_PACKAGE_DEPENDENCIES lists, and to one or more of the above variables
    dnl depending on the package type and other criteria (such as whether or not it
    dnl needs to be installed)
    dnl
    DIR="$SAGE_ROOT"/build/pkgs/SPKG_NAME
    AS_IF([test ! -d "$DIR"], [dnl
        AC_MSG_ERROR([Directory $DIR is missing. Re-run bootstrap.])dnl
    ])
    dnl
    SPKG_VERSION=$(newest_version SPKG_NAME)
    dnl
    dnl Determine package source
    dnl
    m4_case(SPKG_SOURCE,
      [normal], [dnl
        m4_define([in_sdist], [yes])dnl
      ], [dnl pip/script/none (dummy script package)
        dnl Since pip packages are downloaded and installed by pip, we do not
        dnl include them in the source tarball. At the time of this writing,
        dnl all pip packages are optional.
        dnl
        dnl script: We assume that either (a) the sources for an optional script
        dnl package will be downloaded by the script, or (b) that the
        dnl sources of a standard script package are already a part of the
        dnl sage repository (and thus the release tarball). As a result,
        dnl we do not need to download the sources, which is what
        dnl "in_sdist" really means. At the time of this writing, the
        dnl only standard script packages are sage_conf and sagelib.
        dnl The sources of these packages are in subdirectories of
        dnl $SAGE_ROOT/pkgs.
        m4_define([in_sdist], [no])dnl
      ])dnl
    dnl Write out information about the installation tree, using the name of the tree prefix
    dnl variable (SAGE_LOCAL or SAGE_VENV).  The makefile variable of SPKG is called "trees_SPKG",
    dnl note plural, for possible future extension in which an SPKG would be installed into several
    dnl trees.  For example, if we decide to create a separate tree for a venv with the
    dnl Jupyter notebook, then packages such as jupyter_core would have to be installed into
    dnl two trees.
    if test -f "$DIR/trees.txt"; then
        SPKG_TREE_VAR="$(sed "s/#.*//;" "$DIR/trees.txt")"
    else
        SPKG_TREE_VAR=SAGE_LOCAL
        if test -f "$DIR/requirements.txt" -o -f "$DIR/install-requires.txt"; then
            dnl A Python package
            SPKG_TREE_VAR=SAGE_VENV
        fi
    fi
    SAGE_PACKAGE_TREES="${SAGE_PACKAGE_TREES}$(printf '\ntrees_')SPKG_NAME = ${SPKG_TREE_VAR}"

    dnl Determine whether it is installed already
    AS_VAR_SET([is_installed], [no])
    for treevar in ${SPKG_TREE_VAR} SAGE_LOCAL; do
        AS_VAR_COPY([t], [$treevar])
        AS_IF([test -n "$t" -a -d "$t/var/lib/sage/installed/" ], [dnl
            for f in "$t/var/lib/sage/installed/SPKG_NAME"-*; do
                AS_IF([test -r "$f"], [dnl
                    m4_case(SPKG_SOURCE, [normal], [dnl
                        dnl Only run the multiple installation record test for normal packages,
                        dnl not for script packages. We actually do not clean up after those...
                        AS_IF([test "$is_installed" = "yes"], [dnl
                            AC_MSG_ERROR(m4_normalize([
                                multiple installation records for SPKG_NAME:
                                m4_newline($(ls -l "$t/var/lib/sage/installed/SPKG_NAME"-*))
                                m4_newline([only one should exist, so please delete some or all
                                of these files and re-run "$srcdir/configure"])
                            ]))dnl
                        ])
                    ])dnl
                    AS_VAR_SET([is_installed], [yes])
                ])
            done
            dnl Only check the first existing tree, so that we do not issue "multiple installation" warnings
            dnl when SAGE_LOCAL = SAGE_VENV
            break
        ])
    done

    dnl Determine whether package is enabled
    AS_VAR_IF([SAGE_ENABLE_]SPKG_NAME, [if_installed],
          [AS_VAR_SET([SAGE_ENABLE_]SPKG_NAME, $is_installed)])
    AS_VAR_COPY([want_spkg], [SAGE_ENABLE_]SPKG_NAME)

    uninstall_message=""
    SAGE_NEED_SYSTEM_PACKAGES_VAR=SAGE_NEED_SYSTEM_PACKAGES
    m4_case(SPKG_TYPE,
      [standard], [dnl
        AS_VAR_IF([SAGE_ENABLE_]SPKG_NAME, [yes], [dnl
            message="SPKG_TYPE, will be installed as an SPKG"
        ], [dnl
            message="SPKG_TYPE, but disabled using configure option"
        ])
      ], [dnl optional/experimental
        AS_VAR_IF([SAGE_ENABLE_]SPKG_NAME, [yes], [dnl
            message="SPKG_TYPE, will be installed as an SPKG"
        ], [dnl
            message="SPKG_TYPE"
            m4_case(SPKG_SOURCE, [none], [], [dnl
                dnl Non-dummy optional/experimental package, advertise how to install
                message="$message, use \"$srcdir/configure --enable-SPKG_NAME\" to install"
            ])
            SAGE_NEED_SYSTEM_PACKAGES_VAR=SAGE_NEED_SYSTEM_PACKAGES_OPTIONAL
        ])
    ])

    m4_case(SPKG_TYPE,
      [standard], [], [dnl optional|experimental
        m4_define([in_sdist], [no])
        uninstall_message=", use \"$srcdir/configure --disable-SPKG_NAME\" to uninstall"
    ])

    dnl Trac #29629: Temporary solution for Sage 9.1: Do not advertise installing pip packages
    dnl using ./configure --enable-SPKG
    if test -f "$DIR/requirements.txt"; then
        message="SPKG_TYPE pip package; use \"./sage -i SPKG_NAME\" to install"
        uninstall_message="SPKG_TYPE pip package (installed)"
    fi

    SAGE_PACKAGE_VERSIONS="${SAGE_PACKAGE_VERSIONS}$(printf '\nvers_')SPKG_NAME = ${SPKG_VERSION}"

        AS_VAR_PUSHDEF([sage_spkg_install], [sage_spkg_install_]SPKG_NAME)dnl
        AS_VAR_PUSHDEF([sage_require], [sage_require_]SPKG_NAME)dnl
        AS_VAR_PUSHDEF([sage_use_system], [sage_use_system_]SPKG_NAME)dnl

        dnl If $sage_spkg_install_{SPKG_NAME} is set to no, then set inst_<pkgname> to
        dnl some dummy file to skip the installation. Note that an explicit
        dnl "./sage -i SPKG_NAME" will still install the package.
        AS_VAR_IF([sage_spkg_install], [no], [dnl
            dnl We will use the system package (or not required for this platform.)
            SAGE_DUMMY_PACKAGES="${SAGE_DUMMY_PACKAGES} \\$(printf '\n    ')SPKG_NAME"
            AS_VAR_IF([sage_require], [yes], [ message="using system package"
            ],                               [ message="not required on your platform"
            ])
            dnl Trac #31163: Only talk about the SPKG if there is an SPKG
            m4_case(SPKG_SOURCE, [none], [], [dnl
                message="$message; SPKG will not be installed"
            ])
        ], [dnl
            dnl We will not use the system package.
            SAGE_BUILT_PACKAGES="${SAGE_BUILT_PACKAGES} \\$(printf '\n    ')SPKG_NAME"
            AS_VAR_SET_IF([sage_use_system], [dnl
                AS_VAR_COPY([reason], [sage_use_system])
                AS_CASE([$reason],
                [yes],                       [ message="no suitable system package; $message"
                                               AS_VAR_APPEND([$SAGE_NEED_SYSTEM_PACKAGES_VAR], [" SPKG_NAME"])
                                             ],
                [force],                     [ message="no suitable system package; this is an error"
                                               AS_VAR_APPEND([$SAGE_NEED_SYSTEM_PACKAGES_VAR], [" SPKG_NAME"])
                                             ],
                [installed],                 [ message="already installed as an SPKG$uninstall_message" ],
                                             [ message="$reason; $message" ])
            ])
        ])

    dnl Trac #29124: Do not talk about underscore club
    m4_bmatch(SPKG_NAME, [^_], [], [dnl
        formatted_message=$(printf '%-45s%s' "SPKG_NAME-$SPKG_VERSION:" "$message")
        AC_MSG_RESULT([$formatted_message])
    ])
    dnl
        AS_VAR_POPDEF([sage_use_system])dnl
        AS_VAR_POPDEF([sage_require])dnl
        AS_VAR_POPDEF([sage_spkg_install])dnl
    dnl
    m4_case(in_sdist, [yes], [dnl
        SAGE_SDIST_PACKAGES="${SAGE_SDIST_PACKAGES} \\$(printf '\n    ')SPKG_NAME"
    ])

    spkg_line=" \\$(printf '\n    ')SPKG_NAME"
    AS_CASE([$is_installed-$want_spkg],
            [*-yes],  [AS_VAR_APPEND(SAGE_OPTIONAL_INSTALLED_PACKAGES, "$spkg_line")],
            [yes-no], [AS_VAR_APPEND(SAGE_OPTIONAL_UNINSTALLED_PACKAGES, "$spkg_line")])
    dnl
    dnl Determine package dependencies
    dnl
    DEP_FILE="$DIR/dependencies"
    if test -f "$DEP_FILE"; then
        dnl - the # symbol is treated as comment which is removed
        DEPS=`sed 's/^ *//; s/ *#.*//; q' $DEP_FILE`
    else
        m4_define([ORDER_ONLY_DEPS], [])dnl
        m4_case(SPKG_SOURCE,
        [pip], [dnl
            m4_define([ORDER_ONLY_DEPS], [pip])dnl
          ])dnl
        m4_ifval(ORDER_ONLY_DEPS, [dnl
            DEPS="| ORDER_ONLY_DEPS"
        ], [dnl
            DEPS=""
        ])dnl
    fi
    dnl
    SAGE_PACKAGE_DEPENDENCIES="${SAGE_PACKAGE_DEPENDENCIES}$(printf '\ndeps_')SPKG_NAME = ${DEPS}"
    dnl
    dnl Determine package build rules
    m4_case(SPKG_SOURCE,
      [pip], [dnl
        SAGE_PIP_PACKAGES="${SAGE_PIP_PACKAGES} \\$(printf '\n    ')SPKG_NAME"
      ],
      [normal], [dnl
        SAGE_NORMAL_PACKAGES="${SAGE_NORMAL_PACKAGES} \\$(printf '\n    ')SPKG_NAME"
      ],
      [dnl script|none
        SAGE_SCRIPT_PACKAGES="${SAGE_SCRIPT_PACKAGES} \\$(printf '\n    ')SPKG_NAME"
    ])dnl
    dnl
    m4_popdef([SPKG_TYPE])dnl
    m4_popdef([SPKG_NAME])dnl
])

AC_DEFUN([SAGE_SYSTEM_PACKAGE_NOTICE], [
    AS_IF([test -n "$SAGE_NEED_SYSTEM_PACKAGES" -o -n "$SAGE_NEED_SYSTEM_PACKAGES_OPTIONAL"], [
        AC_MSG_NOTICE([

    notice: the following SPKGs did not find equivalent system packages:

       $SAGE_NEED_SYSTEM_PACKAGES  $SAGE_NEED_SYSTEM_PACKAGES_OPTIONAL
        ])
        AC_MSG_CHECKING([for the package system in use])
        SYSTEM=$(build/bin/sage-guess-package-system 2>& AS_MESSAGE_FD)
        AC_MSG_RESULT([$SYSTEM])
        AS_IF([test $SYSTEM != unknown], [
            SYSTEM_PACKAGES=$(build/bin/sage-get-system-packages $SYSTEM $SAGE_NEED_SYSTEM_PACKAGES)
            AS_IF([test -n "$SYSTEM_PACKAGES"], [
                PRINT_SYS="build/bin/sage-print-system-package-command $SYSTEM --verbose=\"    \" --prompt=\"      \$ \" --sudo"
                COMMAND=$(eval "$PRINT_SYS" update && eval "$PRINT_SYS" install $SYSTEM_PACKAGES && SAGE_ROOT="$SAGE_ROOT" eval "$PRINT_SYS" setup-build-env )
                AC_MSG_NOTICE([

    hint: installing the following system packages, if not
    already present, is recommended and may avoid having to
    build them (though some may have to be built anyway):

$COMMAND
])
                AS_VAR_SET([need_reconfig_msg], [yes])
            ])
            SYSTEM_PACKAGES=$(build/bin/sage-get-system-packages $SYSTEM $SAGE_NEED_SYSTEM_PACKAGES_OPTIONAL)
            AS_IF([test -n "$SYSTEM_PACKAGES"], [
                PRINT_SYS="build/bin/sage-print-system-package-command $SYSTEM --verbose=\"    \" --prompt=\"      \$ \" --sudo"
                COMMAND=$(eval "$PRINT_SYS" update && eval "$PRINT_SYS" install $SYSTEM_PACKAGES && SAGE_ROOT="$SAGE_ROOT" eval "$PRINT_SYS" setup-build-env )
                AC_MSG_NOTICE([

    hint: installing the following system packages, if not
    already present, may provide additional optional features:

$COMMAND
])
                AS_VAR_SET([need_reconfig_msg], [yes])
            ])
            dnl Reconfigure message
            AS_VAR_IF([need_reconfig_msg], [yes], [
                AC_MSG_NOTICE([

    hint: After installation, re-run configure using:

      \$ ./config.status --recheck && ./config.status
                ])
            ], [
                AC_MSG_NOTICE([No equivalent system packages for $SYSTEM are known to Sage])
            ])
        ])
    ])
    dnl Deferred errors from --with-system-SPKG=force
    AS_VAR_SET_IF([SAGE_SPKG_ERRORS], [AC_MSG_ERROR([
$SAGE_SPKG_ERRORS
    ])])
])
