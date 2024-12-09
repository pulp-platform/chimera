#include <stdint.h>

#include <stdbool.h> 

static int input_data_len = 64;

static int tempLoop0_in = 1;

static int tempLoop1_in = 1;

static int tempLoop2_in = 1;

static int tempLoop3_in = 1;

static int tempLoop4_in = 1;

static int delta_local_in = 0;

static int spatialStride1_in = 8;

static int tempStride0_in = 8;

static int tempStride1_in = 64;

static int tempStride2_in = 64;

static int tempStride3_in = 64;

static int tempStride4_in = 64;

static int tempLoop0_out = 1;

static int tempLoop1_out = 1;

static int tempLoop2_out = 1;

static int output_data_len = 64;

static int delta_local_out = 64;

static int spatialStride1_out = 8;

static int tempStride0_out = 64;

static int tempStride1_out = 64;

static int tempStride2_out = 64;

static int opcode = 2;

static int TloopLen = 1;

static int reduceLen = 1;

static int8_t DataIn[64]  = {
	-26,
	51,
	-36,
	-114,
	-22,
	-57,
	60,
	-108,
	-26,
	-7,
	82,
	86,
	-54,
	74,
	-41,
	-12,
	-29,
	-25,
	23,
	2,
	21,
	-76,
	-127,
	-41,
	107,
	29,
	-91,
	1,
	63,
	59,
	-108,
	32,
	75,
	-71,
	-107,
	124,
	107,
	-40,
	-80,
	90,
	-70,
	126,
	41,
	91,
	59,
	79,
	-114,
	61,
	61,
	46,
	61,
	-78,
	-21,
	-74,
	115,
	-65,
	120,
	2,
	100,
	-78,
	6,
	-108,
	-56,
	38,
};

static int8_t C_golden[64]  = {
	-26,
	51,
	-36,
	-114,
	-22,
	-57,
	60,
	-108,
	-26,
	-7,
	82,
	86,
	-54,
	74,
	-41,
	-12,
	-29,
	-25,
	23,
	2,
	21,
	-76,
	-127,
	-41,
	107,
	29,
	-91,
	1,
	63,
	59,
	-108,
	32,
	75,
	-71,
	-107,
	124,
	107,
	-40,
	-80,
	90,
	-70,
	126,
	41,
	91,
	59,
	79,
	-114,
	61,
	61,
	46,
	61,
	-78,
	-21,
	-74,
	115,
	-65,
	120,
	2,
	100,
	-78,
	6,
	-108,
	-56,
	38,
};
