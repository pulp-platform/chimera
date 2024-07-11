# ----------------------------------------------------------------------
#
# File: bender.mk
#
# Created: 25.06.2024        
# 
# Copyright (C) 2024, ETH Zurich and University of Bologna.
#
# Author: Moritz Scherer, ETH Zurich
#
# ----------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the License); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an AS IS BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

COMMON_TARGS ?=
COMMON_TARGS += -t snitch_cluster -t cv32a6_convolve -t cva6 -t rtl

SIM_TARGS = -t test -t sim
