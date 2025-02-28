#include <stdint.h>

static int broadcast_C = 1;

static int channel_en_C = 255;

static int Nbatch = 1;

static int H = 1;

static int W = 8;

static int Cin = 8;

static int Cout = 8;

static int Kh = 1;

static int Kw = 1;

static int stride_h = 1;

static int stride_w = 1;

static int pad_h = 0;

static int pad_w = 0;

static int Batch = 1;

static int M = 1;

static int K = 1;

static int N = 1;

static int set_addr_remap_index_A = 2;

static int set_addr_remap_index_B = 2;

static int set_addr_remap_index_C = 2;

static int set_addr_remap_index_D32 = 2;

static int set_addr_remap_index_D8 = 2;

static int interleaved_address = 0;

static int delta_physical_a = 0;

static int delta_physical_b = 64;

static int delta_physical_d8 = 192;

static int delta_physical_c = 128;

static int delta_physical_d32 = 192;

static int delta_local_a = 0;

static int delta_local_b = 32768.0;

static int delta_local_d8 = 98304.0;

static int delta_local_c = 65536.0;

static int delta_local_d32 = 98304.0;

static int Aslstride0 = 1;

static int Aslstride1 = 8;

static int Atlbound0 = 1;

static int Atlstride0 = 8;

static int Atlbound1 = 1;

static int Atlstride1 = 64;

static int Atlbound2 = 1;

static int Atlstride2 = 64;

static int Atlbound3 = 1;

static int Atlstride3 = 0;

static int Atlbound4 = 1;

static int Atlstride4 = 64;

static int Atlbound5 = 1;

static int Atlstride5 = 64;

static int Atlbound6 = 1;

static int Atlstride6 = 64;

static int Bslstride0 = 1;

static int Bslstride1 = 8;

static int Btlbound0 = 1;

static int Btlstride0 = 64;

static int Btlbound1 = 1;

static int Btlstride1 = 64;

static int Btlbound2 = 1;

static int Btlstride2 = 0;

static int Btlbound3 = 1;

static int Btlstride3 = 0;

static int Cslstride0 = 8;

static int Cslstride1 = 64;

static int Ctlbound0 = 1;

static int Ctlstride0 = 256;

static int Ctlbound1 = 1;

static int Ctlstride1 = 256;

static int Ctlbound2 = 1;

static int Ctlstride2 = 256;

static int Ctlbound3 = 1;

static int Ctlstride3 = 256;

static int D32slstride0 = 8;

static int D32slstride1 = 64;

static int D32tlbound0 = 1;

static int D32tlstride0 = 256;

static int D32tlbound1 = 1;

static int D32tlstride1 = 256;

static int D32tlbound2 = 1;

static int D32tlstride2 = 256;

static int D32tlbound3 = 1;

static int D32tlstride3 = 256;

static int D8slstride0 = 1;

static int D8slstride1 = 8;

static int D8tlbound0 = 1;

static int D8tlstride0 = 64;

static int D8tlbound1 = 1;

static int D8tlstride1 = 64;

static int D8tlbound2 = 1;

static int D8tlstride2 = 64;

static int D8tlbound3 = 1;

static int D8tlstride3 = 64;

static int8_t subtraction_a = 0;

static int8_t subtraction_b = 0;

static int8_t A[64]  = {
	-4,
	9,
	4,
	0,
	-3,
	-4,
	8,
	0,
	0,
	-7,
	-3,
	-8,
	-9,
	1,
	-5,
	-9,
	-10,
	1,
	1,
	6,
	-1,
	5,
	4,
	4,
	8,
	1,
	9,
	-8,
	-6,
	8,
	-4,
	-2,
	-4,
	7,
	-7,
	3,
	7,
	-2,
	-9,
	9,
	4,
	-4,
	1,
	-3,
	4,
	-8,
	3,
	6,
	-7,
	7,
	-3,
	-7,
	-9,
	-5,
	-1,
	-7,
	7,
	1,
	-9,
	-1,
	-7,
	3,
	5,
	4,
};

static int8_t B[64]  = {
	-3,
	3,
	-3,
	5,
	2,
	7,
	4,
	2,
	-2,
	4,
	2,
	-10,
	-4,
	-2,
	-10,
	1,
	-3,
	0,
	8,
	6,
	-3,
	-8,
	-8,
	-10,
	-6,
	-1,
	-4,
	-2,
	-4,
	-2,
	-3,
	1,
	-9,
	-10,
	5,
	-6,
	-8,
	1,
	-3,
	-8,
	-10,
	-8,
	-6,
	4,
	3,
	-8,
	-10,
	-6,
	3,
	-4,
	-2,
	4,
	4,
	-1,
	2,
	8,
	-4,
	6,
	9,
	-7,
	-6,
	-4,
	2,
	4,
};

static int C[64]  = {
	23841962,
	-201600484,
	-91061213,
	828299788,
	-743115617,
	-649117882,
	170731194,
	-237146894,
	23841962,
	-201600484,
	-91061213,
	828299788,
	-743115617,
	-649117882,
	170731194,
	-237146894,
	23841962,
	-201600484,
	-91061213,
	828299788,
	-743115617,
	-649117882,
	170731194,
	-237146894,
	23841962,
	-201600484,
	-91061213,
	828299788,
	-743115617,
	-649117882,
	170731194,
	-237146894,
	23841962,
	-201600484,
	-91061213,
	828299788,
	-743115617,
	-649117882,
	170731194,
	-237146894,
	23841962,
	-201600484,
	-91061213,
	828299788,
	-743115617,
	-649117882,
	170731194,
	-237146894,
	23841962,
	-201600484,
	-91061213,
	828299788,
	-743115617,
	-649117882,
	170731194,
	-237146894,
	23841962,
	-201600484,
	-91061213,
	828299788,
	-743115617,
	-649117882,
	170731194,
	-237146894,
};

static int transposed_A = 0;

static int transposed_B = 0;

static int D32[64]  = {
	23841987,
	-201600492,
	-91061192,
	828299783,
	-743115655,
	-649117995,
	170731146,
	-237146738,
	23841861,
	-201600363,
	-91061136,
	828299863,
	-743115354,
	-649117771,
	170731077,
	-237146903,
	23842079,
	-201600560,
	-91061248,
	828299817,
	-743115599,
	-649117879,
	170731213,
	-237146871,
	23841898,
	-201600352,
	-91061207,
	828299737,
	-743115522,
	-649118086,
	170731108,
	-237146795,
	23842013,
	-201600417,
	-91061262,
	828299839,
	-743115807,
	-649117771,
	170731264,
	-237146936,
	23841896,
	-201600500,
	-91061267,
	828299767,
	-743115687,
	-649117898,
	170731286,
	-237146866,
	23841907,
	-201600329,
	-91061113,
	828299891,
	-743115471,
	-649117813,
	170731034,
	-237146758,
	23842001,
	-201600526,
	-91061395,
	828299794,
	-743115717,
	-649118029,
	170731236,
	-237146934,
};

static int bypassSIMD = 0;

static int8_t input_zp_i = -43;

static int8_t output_zp_i = -101;

static int8_t max_int_i = 127;

static int8_t min_int_i = -128;

static int8_t double_round_i = 0;

static int shared_bitpacked_shift0 = 1026304257;

static int shared_bitpacked_shift1 = 453325880;

static int shared_multiplier0 = 1304261659;

static int shared_multiplier1 = -1209289109;

static int shared_multiplier2 = -1346171349;

static int shared_multiplier3 = -358587053;

static int shared_multiplier4 = 1686028061;

static int shared_multiplier5 = 1646176189;

static int shared_multiplier6 = 168973642;

static int shared_multiplier7 = -754432385;

static int8_t D8[64]  = {
	128,
	127,
	127,
	154,
	137,
	128,
	127,
	128,
	128,
	127,
	127,
	154,
	137,
	128,
	127,
	128,
	128,
	127,
	127,
	154,
	137,
	128,
	127,
	128,
	128,
	127,
	127,
	154,
	137,
	128,
	127,
	128,
	128,
	127,
	127,
	154,
	137,
	128,
	128,
	128,
	127,
	127,
	127,
	154,
	137,
	128,
	128,
	128,
	128,
	127,
	127,
	154,
	137,
	128,
	128,
	128,
	127,
	127,
	127,
	154,
	137,
	128,
	127,
	128,
};
