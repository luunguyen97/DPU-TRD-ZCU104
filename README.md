# DPU-TRD-for-ZCU104
Create DPU hardware platform on Vivado 2020.1 and create boot image by Petalinux 2020.1
Based on [DPU-TRD-Vivado-flow](https://github.com/Xilinx/Vitis-AI/tree/master/DPU-TRD/prj/Vivado) in Vitis-AI 1.2 version and [Vitis Custom Embedded Platform Creation Example on ZCU104](https://github.com/Xilinx/Vitis-Tutorials/blob/master/Vitis_Platform_Creation/Introduction/02-Edge-AI-ZCU104/README.md)
## 1. Create DPU hardware platform on Vivado 2020.1
Set the Vivado environment:
```bash
source <Vivado install path>/Vivado/2020.1/settings64.sh
vivado
```
Create normal project with ZCU104 board
Add dpu_ip repository. Go to **IP Catalog**. Right click on **Vivado Repository**. Choose **Add Repository**. Choose **dpu_ip** folder.

Note:The default settings of DPU is B4096 with RAM_USAGE_LOW, CHANNEL_AUGMENTATION_ENABLE, DWCV_ENABLE, POOL_AVG_ENABLE, RELU_LEAKYRELU_RELU6, Softmax. Modify the DPU block in Vivado design to change these default settings. The BRAM resources on ZCU104 is much lower than ZCU102, so we need to use both BRAM and URAM for DPU. In this project, the ``Ultra-RAM Use per DPU`` DPU IP is set at 30 for 1 DPU core, and 40 for 2 DPU cores. 
 
On Tcl conslole in Vivado, run this command to create hardware platform with 1 core DPU from tcl file [dpux1_zcu104.tcl](prj/Vivado/scripts/dpux1_zcu104.tcl).
```bash 
source script/dpux1_zcu104.tcl
```
For platform with 2 DPU cores, you can use this tcl [dpux2_zcu104.tcl](prj/Vivado/scripts/dpux2_zcu104.tcl).
After executing the script, the Vivado IPI block design comes up as shown in the below figure.

![Block Design of DPU TRD Project](./doc/5.2.1-1.png)

- Create HDL Wrapper: Right click on **top.bd** under Design Source and choose **Create HDL Wrapper**, select **Let Vivado manage wrapper and auto-update**. Click **OK**.
- Generate pre-synth design: Select **Generate Block Design** from Flow Navigator. Select **Synthesis Options** to **Global**, it will skip IP synthesis during generation. Click **Generate**.
- Change implamentation strategy from ***Default*** to ***Performance_ExplorePostRoutPhysOpt***. The timing issue happened when using Default implementation strategy.
- Then click on “**Generate Bitstream**”.

###### **Note:** If the user gets any pop-up with “**No implementation Results available**”. Click “**Yes**”. Then, if any pop-up comes up with “**Launch runs**”, Click "**OK**”.

After the generation of bitstream completed.

- Go to **File > Export > Export Hardware**

  ![EXPORT HW](./doc/5.2.1-3.png)
  
- In the Export Hardware window select "**Fixed -> Include bitstream**" and click "**OK**".

  ![INCLUDE BIT](./doc/5.2.1-4.png)

The XSA file is created at $TRD_HOME/prj/Vivado/prj/top_wrapper.xsa

###### **Note:** The actual results might graphically look different than the image shown
## 2. PetaLinux Project Settings
This tutorial shows how to build the Linux image and boot image using the PetaLinux build tool for the DPU hardware created above.

1. Set $PETALINUX environment:
```bash
source <path/to/petalinux-installer>/settings.sh
```
2. We will use BSP of ZCU102 in the DPU-TRD tutorial to create Petalinux project for ZCU104. 
Download ZCU102 board support package:
```
source dpu_petalinux_bsp
./download_bsp.sh
```
3. Create petalinux project from bsp:
```
petalinux-create -t project -s xilinx-zcu102-trd.bsp -n xilinx-zcu104-trd
```
4. Import the hardware description with by giving the path of
the directory containing the .xsa file as follows:
```
cd xilinx-zcu104-trd
petalinux-config --get-hw-description=$TRD_HOME/prj/Vivado/prj/ 
```
5. A petalinux-config menu would be launched, select ***DTG Settings->MACHINE_NAME***, modify it to ***zcu104-revc***. Select ***OK***
6. In ***Firmware Version Configuration***, change Host name from ***xilinx-zcu102-2020_1*** to ***xilinx-zcu104-2020_1***. Similarly Change Production name from ***xilinx-zcu102-2020_1*** to ***xilinx-zcu104-2020_1***.
7. In ***Yocto settings***, change YOCTO_MACHINE_NAME from ***zcu102-zynqmp*** to ***zcu104-zynqmp***
## Customize Root File System, Kernel, Device Tree and U-boot
1. Add user packages by appending the CONFIG_x lines below to the ***<your_petalinux_project_dir>/project-spec/meta-user/conf/user-rootfsconfig*** file. You can just copy this [user-rootfsconfig](ref_files/user-rootfsconfig).

   ***Note: This step is not a must but it makes it easier to find and select all required packages in next step. If this step is skipped, please enable the required packages in next step.***

   Packages for base XRT support:

    ```
   CONFIG_packagegroup-petalinux-xrt
   CONFIG_xrt-dev
    ```
    - packagegroup-petalinux-xrt is required for Vitis acceleration flow. It includes XRT and ZOCL.
    - xrt-dev is required in 2020.1 even when we're not creating a development environment due to a known issue that a soft link required by the deployment environment is packaged into it. XRT 2020.2 fixes this issue.

   Packages for easy system management

    ```
   CONFIG_dnf
   CONFIG_e2fsprogs-resize2fs
   CONFIG_parted
    ```
    - dnf is for package package management
    - parted and e2fsprogs-resize2fs can be used for ext4 partition resize

    *Packages for Vitis-AI dependencies support:*

    ```
   CONFIG_packagegroup-petalinux-vitisai
    ```

   *Packages for natively building Vitis AI applications on target board:*

    ```
   CONFIG_packagegroup-petalinux-self-hosted
   CONFIG_cmake
   CONFIG_packagegroup-petalinux-vitisai-dev
   CONFIG_xrt-dev
   CONFIG_opencl-clhpp-dev
   CONFIG_opencl-headers-dev
   CONFIG_packagegroup-petalinux-opencv
   CONFIG_packagegroup-petalinux-opencv-dev
    ```
    *Packages for running Vitis-AI demo applications with GUI*

    ```
    CONFIG_mesa-megadriver
    CONFIG_packagegroup-petalinux-x11
    CONFIG_packagegroup-petalinux-v4lutils
    CONFIG_packagegroup-petalinux-matchbox
    ```

2. Run ```petalinux-config -c rootfs``` and select ***user packages***, select name of rootfs all the libraries listed above.

   ![petalinux_rootfs.png](./images/petalinux_rootfs.png)

3. *Enable OpenSSH and disable dropbear*
   *Dropbear is the default SSH tool in Vitis Base Embedded Platform. If OpenSSH is used to replace Dropbear, the system could achieve 4x times faster data transmission speed (tested on 1Gbps Ethernet environment). Since Vitis-AI applications may use remote display feature to show machine learning results, using OpenSSH can improve the display experience.*

   a) Still in the RootFS configuration window, go to root directory by select ***Exit*** once.</br>
   b) Go to ***Image Features***.</br>
   c) Disable ***ssh-server-dropbear*** and enable ***ssh-server-openssh*** and click Exit.</br>
   ![ssh_settings.png](./images/ssh_settings.png)


    d) Go to ***Filesystem Packages-> misc->packagegroup-core-ssh-dropbear*** and disable ***packagegroup-core-ssh-dropbear***. Go to ***Filesystem Packages*** level by Exit twice.

    e) Go to ***console  -> network -> openssh*** and enable ***openssh***, ***openssh-sftp-server***, ***openssh-sshd***, ***openssh-scp***. Go to root level by Exit four times.
    
4. Enable Package Management
    a) In rootfs config go to ***Image Features*** and enable ***package-management*** and ***debug_tweaks*** option </br>
    b) Click OK, Exit twice and select Yes to save the changes.
5. Disable CPU IDLE in kernel config (Optional)
   *CPU IDLE would cause CPU IDLE when JTAG is connected. So it is recommended to disable the selection during project development phase. It can be enabled for production to save power.*
   a) Type ```petalinux-config -c kernel```
   b) Ensure the following items are ***TURNED OFF*** by entering 'n' in the [ ] menu selection:

   - ***CPU Power Mangement > CPU Idle > CPU idle PM support***
   - ***CPU Power Management > CPU Frequency scaling > CPU Frequency scaling***
   c) Exit and Save.
6. Install Vitis AI Profiler (Only available in Vitis flow => not use in Vivado flow)
These steps are _not_ required for Vitis AI prebuilt board images for ZCU102 & ZCU104   
a. Configure and Build Petalinux:  
Run _petalinux-config -c kernel_ and Enable these for Linux kernel:
 ```
            General architecture-dependent options ---> [*] Kprobes    
            Kernel hacking  ---> [*] Tracers
            Kernel hacking  ---> [*] Tracers  --->
            			 [*]   Kernel Function Tracer
            			 [*]   Enable kprobes-based dynamic events
            			 [*]   Enable uprobes-based dynamic events
```
      
b. Run _petelinux-config -c rootfs_ and enable this for root-fs:
```
            user-packages  --->  modules   --->
          			[*]   packagegroup-petalinux-self-hosted
```
7. Enable libv4l, libav for video processing
a. create a bbappend file as show below:
   ```
   $ mkdir -p <plnx-proj-root>/project-spec/meta-user/recipes-support/opencv
   $ vim <plnx-proj-root>/project-spec/meta-user/recipes-support/opencv/opencv_%.bbappend

   # opencv_%.bbappend
   PACKAGECONFIG_append = "libv4l libav"
   ```
b. Enable gstreamer packagegroup:
   ```
   petalinux-config -c rootfs ---> Petalinux Package Groups ---> packagegroup-petalinux-gstreamer ---> [*] packagegroup-petalinux-gstreamer
   ```
c. Enable the GStreamer1.0-libav package and whitelist the license flag:
   ```
   gedit <plnx-proj-root>/project-spec/meta-user/conf/petalinuxbsp.conf
   
   IMAGE_INSTALL_append = " gstreamer1.0-libav"
   LICENSE_FLAGS_WHITELIST_append = " commercial_gstreamer1.0-libav"
   ```
9. Update the Device tree.
   Look at the **Address Editor** on Vivado project to see the base-addr of DPU and change its value in  ***project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi***. An example of ***system-user.dtsi*** with 1 core DPU and DPU base-addr = 0x80000000 is shown at [here](ref_files/system-user.dtsi). Note that you need to change base-addr, interrupts, core-num parameters correctly based on your custom Vivado hardfware

Build petalinux project. This step may take some hours to finish.
```
petalinux-build
```
Create a boot image (BOOT.BIN) including FSBL, ATF, bitstream, and u-boot:
```
cd images/linux
petalinux-package --boot --fsbl zynqmp_fsbl.elf --u-boot u-boot.elf --pmufw pmufw.elf --fpga system.bit
```
## 3. Test platform with VART Resnet50 Example 
1. Get HWH file
HWH file is an important file that needed by the VAI_C tool. The file has been created when compile by the Vivado tool. It works together with VAI_C to support model compilation under various DPU configurations.
We can get the HWH file in the following path.
$VIVADO_PRJ/srcs/top/hw_handoff/top.hwh
2. Generate DPU configuration file DCF with Dlet tool

DLet: DLet is host tool designed to parse and extract various edge DPU configuration
parameters from DPU hardware handoff file HWH, generated by Vivado. To use this tools, we need to use the vitis ai docker.
```
./docker_run.sh xilinx/vitis-ai-gpu:latest
conda activate vitis-ai-tensorflow
```
Genetate DPU configuration file DCF with Dlet
```
dlet -f /path/to/hwh/file/
```
Running command dlet -f <bd_name>.hwh, DLet outputs the DPU configuration file
DCF, named in the format of dpu-dd-mm-yyyy-hh-mm.dcf. dd-mm-yyyy-hh-mm is the
timestamp of when the DPU HWH is created. With the specified DCF file, VAI_C compiler
automatically produces DPU code instructions suited for the DPU configuration parameters.
We need to use vitis AI docker to using Dlet.
Change the name of the dfc generated file to ``dpux1_zcu104.dcf``
3. Create ``zcu104_dpu.json`` file. Below is an example of this file:
```
{
    "target"   : "DPUCZDX8G",
    "dcf"      : "/workspace/compile_custom_platform_ZCU104/hardware_platform/DPUx2_ZCU104_v1/zcu104_dpu.dcf",
    "cpu_arch" : "arm64"
}
```
4. Download resnet50_tf model in this [link](https://www.xilinx.com/bin/public/openDownload?filename=tf_resnetv1_50_imagenet_224_224_6.97G_1.2.zip). Extrac this file then we will have a folder name ``tf_resnetv1_50_imagenet_224_224_6.97G_1.2``
5. Compile resnet50_tf model
Run [resnet50_compile.sh](ref_file/resnet50_compile.sh):
```
#!/bin/sh
TARGET=ZCU104
NET_NAME=resnet50
TF_NETWORK_PATH=./tf_resnetv1_50_imagenet_224_224_6.97G_1.2

ARCH=/workspace/compile_custom_platform_ZCU104/hardware_platform/DPUx2_ZCU104_v1/zcu104_dpu.json

vai_c_tensorflow --frozen_pb ${TF_NETWORK_PATH}/quantized/deploy_model.pb \
                 --arch ${ARCH} \
		 --output_dir ${TF_NETWORK_PATH}/vai_c_output_${TARGET}/ \
		 --net_name ${NET_NAME} \
		 --options "{'save_kernel':''}"
```
Take care of the ARCH variable. This variable should point to the ``zcu104_dpu.json`` file we created before. After runing this script, **dpu_resnet50_0.elf** will be generated. 

6. Create ``Vitis-AI/VART/sample/resnet50/model_zcu104`` folder and copy dpu_resnet50_0.elf file to it.

7. Prepare SD card
The user must create the SD card. Refer section "Configuring SD Card ext File System Boot" in page 65 of [ug1144](https://www.xilinx.com/support/documentation/sw_manuals/xilinx2020_1/ug1144-petalinux-tools-reference-guide.pdf)for Petalinux 2020.1:

Copy the image.ub, boot.scr and BOOT.BIN files in **$TRD_HOME/prj/Vivado/dpu_petalinux_bsp/xilinx-zcu104-2020.1/images/linux** to BOOT partition.
```
cp images/linux/BOOT.BIN /media/BOOT/
cp images/linux/image.ub /media/BOOT/
cp images/linux/boot.scr /media/BOOT/
```
Extract the rootfs.tar.gz files in **TRD_HOME/prj/Vivado/dpu_petalinux_bsp/xilinx-zcu104-2020.1/images/linux** to RootFs partition.
```
sudo tar xvf rootfs.tar.gz -C /media/rootfs
```
Copy the folder **VART/sample/resnet50** to **RootFs/home/root** partition
```
sudo cp -r Vitis-AI/VART/sample/resnet50 /media/RootFs/home/root
```

7. Install Vitis AI Runtime on the target board	
	* Download the [Vitis AI Runtime 1.2.1](https://www.xilinx.com/bin/public/openDownload?filename=vitis-ai-runtime-1.2.1.tar.gz).  	
	* Untar the runtime packet and copy the following folder to the board using scp.
	```
	$tar -xzvf vitis-ai-runtime-1.2.1.tar.gz
	$scp -r vitis-ai-runtime-1.2.1/aarch64/centos root@IP_OF_BOARD:~/
	```
	* Install the Vitis AI Runtime on target board. Execute the following command in order.
	```
	#cd ~/centos
	#rpm -ivh --force libunilog-1.2.0-r<x>.aarch64.rpm
	#rpm -ivh --force libxir-1.2.0-r<x>.aarch64.rpm
	#rpm -ivh --force libtarget-factory-1.2.0-r<x>.aarch64.rpm
	#rpm -ivh --force libvart-1.2.0-r<x>.aarch64.rpm
	```


Reboot, after the linux boot, run in the RootFs partition:

```
% cd resnet50
% ./resnet50 model_zcu104/dpu_resnet50_0.elf
```

Expect:
```
score[945]  =  0.992235     text: bell pepper,
score[941]  =  0.00315807   text: acorn squash,
score[943]  =  0.00191546   text: cucumber, cuke,
score[939]  =  0.000904801  text: zucchini, courgette,
score[949]  =  0.00054879   text: strawberry,
```

###### **Note:** The resenet50 test case can support both Vitis and Vivado flow. If you want to run other network. Please refer to the [Vitis AI Github](https://github.com/Xilinx/Vitis-AI) and [Vitis AI User Guide](http://www.xilinx.com/support/documentation/sw_manuals/Vitis_ai/1_0/ug1414-Vitis-ai.pdf).

## 4. Configurate the DPU


The DPU IP provides some user-configurable parameters to optimize resource utilization and customize different features. Different configurations can be selected for DSP slices, LUT, block RAM(BRAM), and UltraRAM utilization based on the amount of available programmable logic resources. There are also options for addition functions, such as channel augmentation, average pooling, depthwise convolution.

The TRD also support the softmax function.
   
For more details about the DPU, please read [DPU IP Product Guide](https://www.xilinx.com/cgi-bin/docs/ipdoc?c=dpu;v=latest;d=pg338-dpu.pdf)

 
#### 4.1 Modify the Frequency

Modify the scripts/trd_prj.tcl to modify the frequency of m_axi_dpu_aclk. The frequency of dpu_2x_clk is twice of m_axi_dpu_aclk.

```
dict set dict_prj dict_param  DPU_CLK_MHz {325}
```

### 4.2 Modify the parameters

Modify the scripts/trd_prj.tcl to modify the parameters which can also be modified on the GUI. 

The TRD supports to modify the following parameters.

- DPU_NUM
- DPU_ARCH
- DPU_RAM_USAGE
- DPU_CHN_AUG_ENA 
- DPU_DWCV_ENA
- DPU_AVG_POOL_ENA
- DPU_CONV_RELU_TYPE
- DPU_SFM_NUM
- DPU_DSP48_USAGE 
- DPU_URAM_PER_DPU 

#### DPU_NUM

The DPU core number is set 2 as default setting. 

```
dict set dict_prj dict_param  DPU_NUM {2}
```
A maximum of 4 cores can be selected on DPU IP. 
###### **Note:** The DPU needs lots of LUTs and RAMs. Use 3 or more DPU may cause the resourse and timing issue.

#### DPU_ARCH

Arch of DPU: The DPU IP can be configured with various convolution architectures which are related to the parallelism of the convolution unit. 
The architectures for the DPU IP include B512, B800, B1024, B1152, B1600, B2304, B3136, and B4096.

```
dict set dict_prj dict_param  DPU_ARCH {4096}
```
###### **Note:** It relates to models. If change, must update models.

#### DPU_RAM_USAGE

RAM Usage: The RAM Usage option determines the total amount of on-chip memory used in different DPU architectures, and the setting is for all the DPU cores in the DPU IP. 
High RAM Usage means that the on-chip memory block will be larger, allowing the DPU more flexibility to handle the intermediate data. High RAM Usage implies higher performance in each DPU core.

Low
```
dict set dict_prj dict_param  DPU_RAM_USAGE {low}
```
High
```
dict set dict_prj dict_param  DPU_RAM_USAGE {high}
```

#### DPU_CHN_AUG_ENA

Channel Augmentation: Channel augmentation is an optional feature for improving the efficiency of the DPU when handling input channels much lower than the available channel parallelism.

Enable 
```
dict set dict_prj dict_param  DPU_CHN_AUG_ENA {1}
```
Disable 
```
dict set dict_prj dict_param  DPU_CHN_AUG_ENA {0}
```
###### **Note:** It relates to models. If change, must update models.

#### DPU_DWCV_ENA

Depthwise convolution: The option determines whether the Depthwise convolution operation will be performed on the DPU or not.

Enable
```
dict set dict_prj dict_param  DPU_DWCV_ENA {1}
```
Disable
```
dict set dict_prj dict_param  DPU_DWCV_ENA {0}
```
###### **Note:** It relates to models. If change, must update models.

#### DPU_AVG_POOL_ENA

AveragePool: The option determines whether the average pooling operation will be performed on the DPU or not.

Enable
```
dict set dict_prj dict_param  DPU_AVG_POOL_ENA {1}
```
Disable
```
dict set dict_prj dict_param  DPU_AVG_POOL_ENA {0}
```
###### **Note:** It relates to models. If change, must update models.

#### DPU_CONV_RELU_TYPE

The ReLU Type option determines which kind of ReLU function can be used in the DPU. ReLU and ReLU6 are supported by default.

RELU_RELU6
```
dict set dict_prj dict_param  DPU_CONV_RELU_TYPE {2}
```
RELU_LEAKRELU_RELU6
```
dict set dict_prj dict_param  DPU_CONV_RELU_TYPE {3}
```
###### **Note:** It relates to models. If change, must update models.

#### DPU_SFM_NUM

Softmax: This option allows the softmax function to be implemented in hardware.

Only use the DPU
```
dict set dict_prj dict_param  DPU_SFM_NUM {0}
```
Use the DPU and Softmax
```
dict set dict_prj dict_param  DPU_SFM_NUM {1}
```

#### DPU_DSP48_USAGE

DSP Usage: This allows you to select whether DSP48E slices will be used for accumulation in the DPU convolution module.

High
```
dict set dict_prj dict_param  DPU_DSP48_USAGE {high}
```
Low
```
dict set dict_prj dict_param  DPU_DSP48_USAGE {low}
```

#### DPU_URAM_PER_DPU

The DPU uses block RAM as the memory unit by default. For a target device with both block RAM and UltraRAM, configure the number of UltraRAM to determine how many UltraRAMs are used to replace some block RAMs. 
The number of UltraRAM should be set as a multiple of the number of UltraRAM required for a memory unit in the DPU. 
An example of block RAM and UltraRAM utilization is shown in the Summary tab section.

```
dict set dict_prj dict_param  DPU_URAM_PER_DPU {0}
```

## 6 Run with Vitis AI Library

For the instroduction of Vitis AI Library, please refer to **Quick Start For Edge** of this page https://github.com/Xilinx/Vitis-AI/tree/master/Vitis-AI-Library
