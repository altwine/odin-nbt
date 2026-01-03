package all_types

import nbt "../../../odin-nbt"
import "core:fmt"

Test_Compound :: struct {
	byteTest:   nbt.Byte      `nbt:"byte_test"`,
	shortTest:  nbt.Short     `nbt:"short_test"`,
	intTest:    nbt.Int       `nbt:"int_test"`,
	longTest:   nbt.Long      `nbt:"long_test"`,
	floatTest:  nbt.Float     `nbt:"float_test"`,
	doubleTest: nbt.Double    `nbt:"double_test"`,
	stringTest: nbt.String    `nbt:"string_test"`,
	byteArray:  nbt.ByteArray `nbt:"byte_array"`,
	intArray:   nbt.IntArray  `nbt:"int_array"`,
	longArray:  nbt.LongArray `nbt:"long_array"`,
}

main :: proc() {
	w: nbt.Writer
	nbt.writer_init(&w, context.allocator)
	defer nbt.writer_destroy(&w)

	nbt.writer_write_compound(&w, Test_Compound {
		byteTest   = 127,
		shortTest  = 32767,
		intTest    = 2147483647,
		longTest   = 9223372036854775807,
		floatTest  = 0.4982314705848694,
		doubleTest = 0.4931287132182315,
		stringTest = "HELLO WORLD THIS IS A TEST STRING ÅÄÖ!",
		byteArray  = nbt.ByteArray{1, 2, 3, 4, 5},
		intArray   = nbt.IntArray{100, 200, 300, 400},
		longArray  = nbt.LongArray{1000, 2000, 3000},
	})

	result := nbt.writer_to_base64(&w)
	defer delete(result)

	fmt.printfln("Result base64 nbt: %s", result)
}
