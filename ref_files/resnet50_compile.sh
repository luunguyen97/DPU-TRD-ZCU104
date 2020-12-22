#!/bin/sh

# Copyright 2019 Xilinx Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


TARGET=ZCU104
NET_NAME=resnet50
DEPLOY_MODEL_PATH=compile
TF_NETWORK_PATH=./tf_resnetv1_50_imagenet_224_224_6.97G_1.2

ARCH=/workspace/compile_custom_platform_ZCU104/hardware_platform/DPUx2_ZCU104_v1/zcu104_dpu.json

vai_c_tensorflow --frozen_pb ${TF_NETWORK_PATH}/quantized/deploy_model.pb \
                 --arch ${ARCH} \
		 --output_dir ${TF_NETWORK_PATH}/vai_c_output_${TARGET}/ \
		 --net_name ${NET_NAME} \
		 --options "{'save_kernel':''}"
