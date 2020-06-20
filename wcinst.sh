#!/bin/bash

replace-spdlog-pkgconfig(){
  # Replace the pkgconfig for spdlog before the WCT configuration
  SPDLOG_PC=$SPDLOG_LIB/pkgconfig
  if [ -d "$SPDLOG_PC" ]; then
      cp -r $SPDLOG_PC /wcdo
      sed -i 's|^prefix.*|prefix='"$SPDLOG_FQ_DIR"'|g' $SPDLOG_PC_DEST/spdlog.pc
  else 
      echo "$SPDLOG_PC does not exist."
  fi
}

wcinst-init(){

  # https://cdcvs.fnal.gov/redmine/projects/larwirecell/repository
  larsoft_version=v08_55_01
  larwirecell_version=v08_12_15
  dunetpc_version=v08_55_01
  sl7img=

  # download wcdo.sh
  if ! [ -x "$(command -v wcdo.sh)" ]; then
    echo '[warning] wcdo.sh is not found or executable.' >&2
    echo -e "Would you like to download wcdo.sh now ([y]/n)? "
    read use_wcdo_download
    if [ "$use_wcdo_download" = "y" ] || ["$use_wcdo_download" = ""];then
      wget https://www.phy.bnl.gov/~wgu/protodune/wcinst/wcdo.sh
      export PATH=$(pwd):$PATH
      chmod +x wcdo.sh
    else
      echo
      echo "Please setup wcdo.sh properly and run this installer again."
      echo
      exit 1
    fi
  fi

  echo
  read -p "Press [Enter] key to continue..."
  
  clear
  echo
  echo "Please verify the software version."
  echo -e "larsoft: $larsoft_version\nlarwirecell: $larwirecell_version\ndunetpc: $dunetpc_version\n"
  echo "Are they the right versions ([y]/n)? "
  read larinfo
  echo
  
  if [ "$larinfo" = "n" ];then
    echo "Please specify the desired versions in format (eg, v08_08_00):"
    echo -n "larsoft_version="
    read larsoft_version
    echo -n "larwirecell_version="
    read larwirecell_version
    echo -n "dunetpc_version="
    read dunetpc_version
  fi
  
  echo
  if [ "$sl7img" = "" ];then 
    echo -e "Please choose your source for the sl7 image:\n 1) an existing copy;\n 2) automated download.\n\n"
    echo "Which one do you want (1/[2])?"
    read sl7opt
    if [ "$sl7opt" = "2" ] || [ "$sl7opt" = "" ];then
      wcdo.sh get-image sl7krb
    else
      echo
      # echo "Please type your path below (eg, path_to_sl7img=../sl7krb.simg):"
      echo "Please type your path below ([../sl7krb.simg]):"
      echo "Note: your current working directory is $(pwd)"
      echo
      echo -n "path_to_sl7img="
      read sl7img
      ln -s $sl7img sl7krb.simg
    fi
  fi

  # make a local copy of the environment
  rcfile=".wcinst.rc"
  touch $rcfile
  cat <<EOF > "$rcfile"
larsoft_version=${larsoft_version}
larwirecell_version=${larwirecell_version}
dunetpc_version=${dunetpc_version}
EOF

  wcdo.sh init
  wcdo.sh wct
  wcdo.sh make-project myproj sl7krb
  
  # echo
  # echo "Please fill the larsoft version in wcdo-local-myproj.rc as follows (default editor: vim)."
  # echo
  # echo wcdo_mrb_project_name='"'larsoft'"'
  # echo wcdo_mrb_project_version='"'$larsoft_version'"'
  # echo wcdo_mrb_project_quals='"'e19:prof'"'
  # echo
  # read -p "Press [Enter] key to continue..."
  # 
  # vim wcdo-local-myproj.rc
  
  sed -i '/^wcdo_mrb_project_name/ s/.*/wcdo_mrb_project_name="'larsoft'"/g' wcdo-local-myproj.rc
  sed -i '/^wcdo_mrb_project_version/ s/.*/wcdo_mrb_project_version="'$larsoft_version'"/g' wcdo-local-myproj.rc
  sed -i '/^wcdo_mrb_project_quals/ s/.*/wcdo_mrb_project_quals="'e19:prof'"/g' wcdo-local-myproj.rc
  
  echo
  echo ----------- Please Type the Command Below This Line ----------------
  echo
  echo ./wcinst.sh bootstrap
  echo
  echo --------------------------------------------------------------------
  echo

  read -p "Press [Enter] key to continue..."

  # go inside the singularity container
  ./wcdo-myproj.sh
}

wcinst-bootstrap(){
 source .wcinst.rc
 source wcdo-myproj.rc
 source wcdo-local-myproj.rc

 source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
 path-prepend $wcdo_ups_products PRODUCTS
 wcdo-mrb-init
 wcdo-mrb-add-source larwirecell $larwirecell_version $larwirecell_version
 wcdo-ups-declare wirecell wctdev
 setup wirecell wctdev -q e19:prof

 export SPDLOG_PC_DEST=/wcdo/pkgconfig
 export PKG_CONFIG_PATH=$SPDLOG_PC_DEST:$PKG_CONFIG_PATH
 replace-spdlog-pkgconfig

 wcdo-ups-wct-configure-source
 ./wcb -p --notests install
 setup wirecell wctdev -q e19:prof
 wcdo-wirecell-path default
 echo
 
 # echo "Please change the wirecell version as follows (default editor: vim)."
 # echo "wirecell v0_xx_xx ==> wirecell wctdev"
 # echo
 # read -p "Press [Enter] key to continue..."
 # vim /wcdo/src/mrb/srcs/larwirecell/ups/product_deps
 
 sed -i '/^wirecell/ s/.*/wirecell        wctdev/g' /wcdo/src/mrb/srcs/larwirecell/ups/product_deps 

 mrbsetenv
 mrb i -j4
 mrbslp
 echo
 echo "--- test 1: ups active | grep wirecell"
 ups active | grep wirecell
 echo
 echo "--- test 2: ups list -aK+ wirecell | head"
 ups list -aK+ wirecell | head
 echo "Successful installation!"
  
  #echo "Here is an example of wcdo-local-myproj.rc"
  #echo "After you update your wcdo-local-myproj.rc, try ./wcdo-myproj.sh"
  #echo

  echo
  echo ----------- Please Restart The Singularity Container ----------------
  echo
  echo exit
  echo 
  echo ./wcdo-myproj.sh
  echo
  echo ---------------------------------------------------------------------
  echo


  read -p "Press [Enter] key to continue..."

  # add environment into wcdo-local-myproj.rc
  rcfile="/wcdo/wcdo-local-myproj.rc"
  touch $rcfile
  cat <<EOF >> "$rcfile"
source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
setup dunetpc ${dunetpc_version} -q e19:prof

path-prepend \$wcdo_ups_products PRODUCTS
wcdo-mrb-init
wcdo-ups-init
setup wirecell wctdev -q e19:prof
# export WIRECELL_PATH=/wcdo/src/wct/cfg:/wcdo/share/wirecell/data
# echo WIRECELL_PATH=\$WIRECELL_PATH
mrbsetenv
mrbslp
export FHICL_FILE_PATH=\$WIRECELL_PATH:\$FHICL_FILE_PATH
export PKG_CONFIG_PATH=$SPDLOG_PC_DEST:\$PKG_CONFIG_PATH

find-fhicl(){
  fhicl_file=\$1
  for path in \`echo \$FHICL_FILE_PATH  | sed -e 's/:/\n/g'\`;do find \$path -name "\$fhicl_file"  2>/dev/null;done
}

art-dump(){
  art_file=\$1
  lar -n1 -c eventdump.fcl \$art_file
}

mrbcompile(){
  mrbsetenv;
  mrb i -j32
  mrbslp
}

alias ls='ls --color'

EOF

}

wcinst-help(){
  cat << EOF
  wcinst.sh
    - a help installer for wirecell + singularity
    - based on wcdo.sh (https://github.com/WireCell/wire-cell-singularity)

  usage:
    - show this help message
      - ./wcinst.sh help

    - get wirecell toolkit in three steps
      - ./wcinst.sh init # in host shell
      - ./wcinst.sh bootstrap # in singularity container
      - exit & relogin singularity (./wcdo-myproj.sh)
EOF
}

wcinst-msg(){
  echo
  echo ----------- Please Type the Command ------------------
  echo
  echo ./wcinst.sh bootstrap
  echo
  echo ------------------------------------------------------
}

cmd="${1:-help}"; shift
wcinst-$cmd $@
