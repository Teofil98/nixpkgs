{
  stdenv,
  lib,
  fetchFromGitHub,
  kernel,
  kernelModuleMakeFlags,
  nvidia_x11,
  hash,
  patches ? [ ],
  broken ? false,
  mlnx_ofed,
}:

stdenv.mkDerivation {
  pname = "nvidia-open";
  version = "${kernel.version}-${nvidia_x11.version}";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "open-gpu-kernel-modules";
    rev = nvidia_x11.version;
    inherit hash;
  };

  inherit patches;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  # TODO
  # set OFA_DIR nvidia-peermem.Kbuild
 #  postPatch to change the MLNX_OFE_KERNEL_DIR from conftest.sh to the nix/store of mlnx_ofed
 # -- # MLNX_OFED_KERNEL to nix/store

  postPatch = ''
    substituteInPlace kernel-open/nvidia-peermem/nvidia-peermem.Kbuild kernel-open/conftest.sh \
      --replace-fail "/usr/src/ofa_kernel" \
      "${mlnx_ofed}/lib/modules/${kernel.modDirVersion}/extra/mlnx-ofa_kernel"


    substituteInPlace kernel-open/conftest.sh \
  --replace-fail \
  "if check_for_ib_peer_memory_symbols \"\$OUTPUT\" || \\" \
  "if check_for_ib_peer_memory_symbols \"\$OUTPUT\" || check_for_ib_peer_memory_symbols \"\$MLNX_OFED_KERNEL_DIR\"; then"

substituteInPlace kernel-open/conftest.sh \
  --replace-fail \
  "           check_for_ib_peer_memory_symbols \"\$MLNX_OFED_KERNEL_DIR/\$ARCH/\$KERNELRELEASE\" || \\" \
  ""

substituteInPlace kernel-open/conftest.sh \
  --replace-fail \
  "           check_for_ib_peer_memory_symbols \"\$MLNX_OFED_KERNEL_DIR/\$KERNELRELEASE\" || \\" \
  ""

substituteInPlace kernel-open/conftest.sh \
  --replace-fail \
  "           check_for_ib_peer_memory_symbols \"\$MLNX_OFED_KERNEL_DIR/default\" || \\" \
  ""

substituteInPlace kernel-open/conftest.sh \
  --replace-fail \
  "           check_for_ib_peer_memory_symbols \"\$VAR_DKMS_SOURCES_DIR\"; then" \
  ""


    #substituteInPlace kernel-open/conftest.sh \
    #  --replace-fail "/usr/src/ofa_kernel" \
    #  "${mlnx_ofed}/lib/modules/${kernel.modDirVersion}/extra/mlnx-ofa_kernel"

       # Verify the patch was applied
      grep -n "OFA_DIR" kernel-open/nvidia-peermem/nvidia-peermem.Kbuild
      grep -n "MLNX_OFED_KERNEL_DIR" kernel-open/conftest.sh
  '';


  makeFlags =
    kernelModuleMakeFlags
    ++ [
      "IGNORE_PREEMPT_RT_PRESENCE=1"
      "SYSSRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/source"
      "SYSOUT=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      "MODLIB=$(out)/lib/modules/${kernel.modDirVersion}"
      "DATE="
      "TARGET_ARCH=${stdenv.hostPlatform.parsed.cpu.name}"
    ]
    ++ lib.optionals stdenv.cc.isClang [
      "C_INCLUDE_PATH=${lib.getLib stdenv.cc.cc}/lib/clang/${lib.versions.major stdenv.cc.cc.version}/include"
    ];

  installTargets = [ "modules_install" ];
  enableParallelBuilding = true;

  meta = {
    description = "NVIDIA Linux Open GPU Kernel Module";
    homepage = "https://github.com/NVIDIA/open-gpu-kernel-modules";
    license = with lib.licenses; [
      gpl2Plus
      mit
    ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    maintainers = with lib.maintainers; [ nickcao ];
    inherit broken;
  };
}
