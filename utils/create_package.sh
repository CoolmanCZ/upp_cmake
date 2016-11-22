#!/bin/bash

localdir=`pwd`
upp_git_revision=`date +%Y-%m-%d`
upp_git_revision_spec=`date +%Y%m%d`

git_dir_path="../"
git_dir_name="github.upp_git"

upp_src_name="upp-x11-src-${upp_git_revision}"
upp_src_name_archive="${upp_src_name}.tar.bz2"
upp_src_name_archive_list="upp_archive_list.txt"

sed_tmp1="sed_tmp1.txt"
sed_tmp2="sed_tmp2.txt"
cat_tmp1="cat_tmp1.txt"
##delete_pretty_printers=""

# check archive name with svn revision
if [ -e $upp_src_name_archive ]; then
    echo "Archive already exists!"
    exit 0;
fi

# remove rejected patched files
rm -f `find ${git_dir_path}${git_dir_name} -name '*.rej' -type f`

# prepare source list to archive
echo -n "Prepare source list   "

##if [ ! -f ${git_dir_path}${git_dir_name}/uppsrc/ide/Debuggers/PrettyPrinters.brcc ]; then
##    delete_pretty_printers="yes"
##    cp ${localdir}/PrettyPrinters.brcc ${git_dir_path}${git_dir_name}/uppsrc/ide/Debuggers
##fi

# prepare list of exaple, ... files
find ${git_dir_path}${git_dir_name}/bazaar -name '*' -type f > $upp_src_name_archive_list
find ${git_dir_path}${git_dir_name}/examples -name '*' -type f >> $upp_src_name_archive_list
find ${git_dir_path}${git_dir_name}/reference -name '*' -type f >> $upp_src_name_archive_list
find ${git_dir_path}${git_dir_name}/tutorial -name '*' -type f >> $upp_src_name_archive_list
find ${git_dir_path}${git_dir_name}/uppsrc -name '*' -type f >> $upp_src_name_archive_list

# remove version system direcories and files
sed '/\.git/d;/\$.tpp/d' $upp_src_name_archive_list > $sed_tmp1
find ${git_dir_path}${git_dir_name}/uppsrc/ -maxdepth 1 -not -iname "*.h" -type f > $sed_tmp2
diff $sed_tmp1 $sed_tmp2 | sed '/^[0-9][0-9]*/d; s/^. //; /^---$/d' > $upp_src_name_archive_list

cat > ${cat_tmp1} << EOF
${git_dir_path}${git_dir_name}/uppsrc/Makefile
${git_dir_path}${git_dir_name}/upp.spec
${git_dir_path}${git_dir_name}/GCC.bm
${git_dir_path}${git_dir_name}/Makefile
${git_dir_path}${git_dir_name}/doinstall
${git_dir_path}${git_dir_name}/domake
${git_dir_path}${git_dir_name}/readme
EOF

cat ${cat_tmp1} >> ${upp_src_name_archive_list}

echo "... DONE"

# create Makefile
echo -n "Prepare files         "
cp $localdir/uppsrc_Makefile ${git_dir_path}${git_dir_name}/uppsrc/Makefile
cp $localdir/${git_dir_path}${git_dir_name}/uppbox/Scripts/upp.spec ${git_dir_path}${git_dir_name}/upp.spec

# create GCC.bm file
cat > ${git_dir_path}${git_dir_name}/GCC.bm << EOF
BUILDER         = "GCC";
COMPILER        = "g++";
DEBUG_INFO      = "2";
DEBUG_BLITZ     = "1";
DEBUG_LINKMODE  = "1";
DEBUG_OPTIONS   = "-O0";
DEBUG_FLAGS     = "";
RELEASE_BLITZ           = "0";
RELEASE_LINKMODE        = "1";
RELEASE_OPTIONS         = "-O3 -ffunction-sections -fdata-sections";
RELEASE_SIZE_OPTIONS    = "-Os -finline-limit=20 -ffunction-sections -fdata-sections";
RELEASE_FLAGS   = "";
RELEASE_LINK    = "-Wl,--gc-sections";
DEBUGGER        = "gdb";
PATH            = "";
INCLUDE         = "$INCLUDEDIR";
LIB             = "$LIBDIR";
REMOTE_HOST     = "";
REMOTE_OS       = "";
REMOTE_TRANSFER = "";
REMOTE_MAP      = "";
LINKMODE_LOCK   = "0";
EOF

# create Makefile
cat > ${git_dir_path}${git_dir_name}/Makefile << EOF
.PHONY: all install clean

all:
	sh domake

install:
	sh doinstall

clean:
	rm -r uppsrc/_out
	rm uppsrc/ide.out
EOF

# create doinstall file
cat > ${git_dir_path}${git_dir_name}/doinstall << EOF
cp ./theide ~/theide

mkdir ~/upp
mkdir ~/upp.out
mkdir ~/MyApps

cp -r uppsrc ~/upp
cp -r examples ~/upp
cp -r bazaar ~/upp
cp -r tutorial ~/upp
cp -r reference ~/upp

rm -r ~/upp/uppsrc/_out
rm -r ~/upp/uppsrc/ide.out

mkdir ~/.upp
mkdir ~/.upp/theide

cp GCC.bm ~/.upp/theide

echo UPP = \"$HOME/upp/uppsrc\"\;OUTPUT = \"$HOME/upp.out\"\; > ~/.upp/theide/uppsrc.var
echo UPP = \"$HOME/upp/examples\;$HOME/upp/uppsrc\"\;OUTPUT = \"$HOME/upp.out\"\; > ~/.upp/theide/examples.var
echo UPP = \"$HOME/upp/reference\;$HOME/upp/uppsrc\"\;OUTPUT = \"$HOME/upp.out\"\; > ~/.upp/theide/reference.var
echo UPP = \"$HOME/upp/tutorial\;$HOME/upp/uppsrc\"\;OUTPUT = \"$HOME/upp.out\"\; > ~/.upp/theide/tutorial.var
echo UPP = \"$HOME/upp/bazaar\;$HOME/upp/uppsrc\"\;OUTPUT = \"$HOME/upp.out\"\; > ~/.upp/theide/bazaar.var
echo UPP = \"$HOME/MyApps\;$HOME/upp/uppsrc\"\;OUTPUT = \"$HOME/upp.out\"\; > ~/.upp/theide/MyApps.var
EOF

#create domake file
cat > ${git_dir_path}${git_dir_name}/domake << EOF
if [ ! -f /usr/lib/libdl.so ]
then
	cd uppsrc
	sed -e s/-ldl//g Makefile >Makefile2
	rm Makefile
	mv Makefile2 Makefile
	cd ..
fi

if which gmake
then
	gmake -C uppsrc
else
	make -C uppsrc
fi

if [ -f uppsrc/ide.out ]; then
    cp uppsrc/ide.out ./theide
fi

if [ ! -L ide ] && [ -f ./theide ]; then
    ln -s ./theide ide
fi

EOF

# create readme file
cat > ${git_dir_path}${git_dir_name}/readme << EOF
Use 'make' to compile TheIDE. It will generate ~/theide.

Use 'make install' to prepare standard U++ environment. It will create ~/upp
directory to store U++ library sources, MyApps to store your application
sources and ~/upp.out as output for intermediate files.

Then start playing with U++ by invoking ~/theide (you might want to put it elsewhere later).
EOF

echo "... DONE"

# update IDE version in the upp.spec file by sed
sed -e "s/version [0-9]*/version $upp_git_revision_spec/g" -i ${git_dir_path}${git_dir_name}/upp.spec
echo "#define IDE_VERSION \"$upp_git_revision\"" > ${git_dir_path}${git_dir_name}/uppsrc/ide/version.h

# install patches
#echo "Execute patches"
#cd ${git_dir_path}${git_dir_name}
#for patch_name in `find $localdir -maxdepth 1 -type f -name uppsrc_*.patch`; do
#    cat $patch_name | patch -p1 >> $localdir/uppsrc_patch-${upp_git_revision}.txt && echo "Patch $patch_name OK" || echo "Patch $patch_name failed!"; exit 101
#done
#echo "Execute patches        ....DONE"

# create tar.bz2 archive
echo -n "Create archive        "
cd $localdir
tar --transform "s,${git_dir_name},${upp_src_name}," -c -j -f $upp_src_name_archive -T $upp_src_name_archive_list
echo "... DONE"

# remove tmp files
echo -n "Remove tmp files      "
rm `cat $cat_tmp1`
rm $cat_tmp1 $sed_tmp1 $sed_tmp2 $upp_src_name_archive_list
echo "... DONE"

# revert ide version from git repository
echo "#define IDE_VERSION    \"\"" > ${git_dir_path}${git_dir_name}/uppsrc/ide/version.h

##if [ -n delete_pretty_printers ]; then
##    echo "Delete ${git_dir_path}${git_dir_name}/uppsrc/ide/Debuggers/PrettyPrinters.brcc"
##    rm ${git_dir_path}${git_dir_name}/uppsrc/ide/Debuggers/PrettyPrinters.brcc
##fi;

