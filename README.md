# Used to create RHEL image for Azure

Built on Mac OS and for building an image that will work with [Microsoft's OpenShift deployment scripts](https://github.com/Microsoft/openshift-container-platform) which are hosted on GitHub.

Have gawk, qemu, and VirtualBox installed (via brew)

Run the scripts in the order they are numbered.

1 - Inside a fresh RHEL VM that is subscripted to RHSM

2 - After you shutdown that VM from the host OS to compress, convert, and copy it to Azure
    (You will need a storage account already setup)

