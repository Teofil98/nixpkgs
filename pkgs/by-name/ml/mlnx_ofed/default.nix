{
  lib,
  stdenv,
  pkgs,
  kernel,
  ncurses,
  automake,
  autoconf,
}: let
  KERNELDIR = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
  KERNELSRC = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/src";
in
  stdenv.mkDerivation {
    pname = "mlnx-ofed";
    version = "26.01";

    src = pkgs.fetchurl {
      url = "https://linux.mellanox.com/public/repo/doca/3.3.0/SOURCES/mlnx_ofed/MLNX_OFED_SRC-debian-26.01-1.0.0.0.tgz";
      sha256 = "sha256-7VWXpUfC1buFi0PyMF7Bn1ObxwxOXtdapsaJenFVaNM=";
    };
    #	src=./MLNX_OFED_SRC-26.01-1.0.0.0/SOURCES/mlnx-ofed-kernel-26.01.OFED.26.01.1.0.0.1;

    unpackPhase = ''
      runHook preUnpack
      tar -xzf $src
      cd MLNX_OFED_SRC-26.01-1.0.0.0/SOURCES

      tar -xzf mlnx-ofed-kernel_26.01.OFED.26.01.1.0.0.1.orig.tar.gz
      cd mlnx-ofed-kernel-26.01.OFED.26.01.1.0.0.1

      sourceRoot=$(pwd)

      runHook postUnpack
    '';

    postPatch = ''
       	substituteInPlace configure makefile \
         --replace "/usr/bin/" ""

       	substituteInPlace configure makefile \
         --replace "/bin/" ""

      substituteInPlace configure \
         --replace-fail \
         'VALUE=$(tac ''${KSRC_OBJ}/include/*/autoconf.h | grep -m1 ''${VAR} | sed -ne '"'"'s/.*\([01]\)$/\1/gp'"'"')' \
         'VALUE=$(grep -h "''${VAR}" ''${KSRC_OBJ}/include/*/autoconf.h  | tail -n1  | sed -ne '"'"'s/.*\([01]\)$/\1/p'"'"' )'

    '';

    nativeBuildInputs =
      [
        ncurses
        automake
        autoconf
      ]
      ++ kernel.moduleBuildDependencies;

    preConfigure = ''
      mkdir -p /etc
      		echo 'ID=nixos' > /etc/os-release
    '';

    configurePhase = ''
      patchShebangs .
      ./configure --kernel-sources=${KERNELDIR}  \
      		    --default \
      			--build-dummy-mods \
      			--with-njobs=$NIX_BUILD_CORES \
      			--with-linux=${KERNELSRC} \
      			--with-linux-obj=${KERNELDIR} \
    '';

    buildPhase = ''
      make -j$NIX_BUILD_CORES
    '';

    installPhase = ''
      make -C ${kernel.dev}/lib/modules/${kernel.version}/build \
      	M="$PWD" \
      	INSTALL_MOD_PATH=$out \
      	INSTALL_MOD_DIR=extra/mlnx-ofa_kernel \
      	modules_install

		# Export symvers so downstream modules can link against our symbols
  		install -Dm644 Module.symvers $out/lib/modules/${kernel.modDirVersion}/extra/mlnx-ofa_kernel/Module.symvers
    # Copy in out the include dir
      cp -r include $out/lib/modules/${kernel.modDirVersion}/extra/mlnx-ofa_kernel
    '';
  }
