package nbt

import "base:intrinsics"
import "base:runtime"
import "vendor:zlib"
import "core:encoding/base64"
import "core:strings"
import "core:bytes"
import "core:mem"
import "core:fmt"
import "core:c"

Tag :: enum {
	End,
	Byte,
	Short,
	Int,
	Long,
	Float,
	Double,
	ByteArray,
	String,
	List,
	Compound,
	IntArray,
	LongArray,
}

Byte :: i8
Short :: i16
Int :: i32
Long :: i64
Float :: f32
Double :: f64
String :: string
ByteArray :: []i8
IntArray :: []i32
LongArray :: []i64

@(private)
buffer_write :: proc {
	buffer_write_string,
	buffer_write_byte,
	buffer_write_tag,
}

@(private)
buffer_write_be :: proc {
	buffer_write_f32_be,
	buffer_write_f64_be,
	buffer_write_i16_be,
	buffer_write_i32_be,
	buffer_write_i64_be,
	buffer_write_u16_be,
}

@(private)
buffer_write_u16_be :: proc(buf: ^bytes.Buffer, value: u16) {
	bytes.buffer_write_byte(buf, byte(value >> 8))
	bytes.buffer_write_byte(buf, byte(value))
}

@(private)
buffer_write_i16_be :: proc(buf: ^bytes.Buffer, value: i16) {
	u := transmute(u16)value
	bytes.buffer_write_byte(buf, byte(u >> 8))
	bytes.buffer_write_byte(buf, byte(u))
}

@(private)
buffer_write_i32_be :: proc(buf: ^bytes.Buffer, value: i32) {
	u := transmute(u32)value
	bytes.buffer_write_byte(buf, byte(u >> 24))
	bytes.buffer_write_byte(buf, byte(u >> 16))
	bytes.buffer_write_byte(buf, byte(u >> 8))
	bytes.buffer_write_byte(buf, byte(u))
}

@(private)
buffer_write_i64_be :: proc(buf: ^bytes.Buffer, value: i64) {
	u := transmute(u64)value
	bytes.buffer_write_byte(buf, byte(u >> 56))
	bytes.buffer_write_byte(buf, byte(u >> 48))
	bytes.buffer_write_byte(buf, byte(u >> 40))
	bytes.buffer_write_byte(buf, byte(u >> 32))
	bytes.buffer_write_byte(buf, byte(u >> 24))
	bytes.buffer_write_byte(buf, byte(u >> 16))
	bytes.buffer_write_byte(buf, byte(u >> 8))
	bytes.buffer_write_byte(buf, byte(u))
}

@(private)
buffer_write_f32_be :: proc(buf: ^bytes.Buffer, value: f32) {
	u := transmute(u32)value
	bytes.buffer_write_byte(buf, byte(u >> 24))
	bytes.buffer_write_byte(buf, byte(u >> 16))
	bytes.buffer_write_byte(buf, byte(u >> 8))
	bytes.buffer_write_byte(buf, byte(u))
}

@(private)
buffer_write_f64_be :: proc(buf: ^bytes.Buffer, value: f64) {
	u := transmute(u64)value
	bytes.buffer_write_byte(buf, byte(u >> 56))
	bytes.buffer_write_byte(buf, byte(u >> 48))
	bytes.buffer_write_byte(buf, byte(u >> 40))
	bytes.buffer_write_byte(buf, byte(u >> 32))
	bytes.buffer_write_byte(buf, byte(u >> 24))
	bytes.buffer_write_byte(buf, byte(u >> 16))
	bytes.buffer_write_byte(buf, byte(u >> 8))
	bytes.buffer_write_byte(buf, byte(u))
}

@(private)
buffer_write_string :: proc(buf: ^bytes.Buffer, value: string) {
	bytes.buffer_write_string(buf, value)
}

@(private)
buffer_write_byte :: proc(buf: ^bytes.Buffer, value: byte) {
	bytes.buffer_write_byte(buf, value)
}

@(private)
buffer_write_tag :: proc(buf: ^bytes.Buffer, value: Tag) {
	bytes.buffer_write_byte(buf, byte(value))
}

Writer :: struct {
	buf:   bytes.Buffer,
	alloc: mem.Allocator,
}

writer_init :: proc(w: ^Writer, allocator := context.allocator) {
	bytes.buffer_init_allocator(&w.buf, 0, 1024, allocator)
	w.alloc = allocator
}

writer_reset :: proc(w: ^Writer) {
	bytes.buffer_reset(&w.buf)
}

writer_length :: proc(w: ^Writer) -> int {
	return bytes.buffer_length(&w.buf)
}

writer_destroy :: proc(w: ^Writer) {
	bytes.buffer_destroy(&w.buf)
}

// Compresses underlying buffer and encodes it using base64 to string
writer_to_base64 :: proc(w: ^Writer) -> string {
	context.allocator = w.alloc
	data := w.buf.buf[:]

	if len(data) == 0 {
		return ""
	}

	s: zlib.z_stream

	zlib.deflateInit2(&s, zlib.DEFAULT_COMPRESSION, zlib.DEFLATED, 31, 8, zlib.DEFAULT_STRATEGY)
	defer zlib.deflateEnd(&s)

	max_size := zlib.deflateBound(&s, zlib.uLong(len(data)))
	compressed := make([]byte, max_size, w.alloc)
	defer delete(compressed)

	s.next_in = cast(^zlib.Bytef)&data[0]
	s.next_out = cast(^zlib.Bytef)&compressed[0]
	s.avail_in = zlib.uInt(len(data))
	s.avail_out = zlib.uInt(len(compressed))

	zlib.deflate(&s, zlib.FINISH)
	compressed = compressed[:s.total_out]
	encoded := base64.encode(compressed, allocator=w.alloc)

	return encoded
}

writer_write_string :: proc(w: ^Writer, name: string, value: String) {
	buffer_write_tag(&w.buf, .String)
	buffer_write_u16_be(&w.buf, u16(len(name)))
	buffer_write_string(&w.buf, name)
	buffer_write_u16_be(&w.buf, u16(len(value)))
	buffer_write_string(&w.buf, value)
}

writer_write_int :: proc(w: ^Writer, name: string, value: Int) {
	buffer_write_tag(&w.buf, .Int)
	buffer_write_u16_be(&w.buf, u16(len(name)))
	buffer_write_string(&w.buf, name)
	buffer_write_i32_be(&w.buf, i32(value))
}

writer_write_byte :: proc(w: ^Writer, name: string, value: byte) {
	buffer_write_tag(&w.buf, .Byte)
	buffer_write_u16_be(&w.buf, u16(len(name)))
	buffer_write_string(&w.buf, name)
	buffer_write_byte(&w.buf, value)
}

writer_write_short :: proc(w: ^Writer, name: string, value: Short) {
	buffer_write_tag(&w.buf, .Short)
	buffer_write_u16_be(&w.buf, u16(len(name)))
	buffer_write_string(&w.buf, name)
	buffer_write_i16_be(&w.buf, i16(value))
}

writer_write_long :: proc(w: ^Writer, name: string, value: Long) {
	buffer_write_tag(&w.buf, .Long)
	buffer_write_u16_be(&w.buf, u16(len(name)))
	buffer_write_string(&w.buf, name)
	buffer_write_i64_be(&w.buf, i64(value))
}

writer_write_float :: proc(w: ^Writer, name: string, value: Float) {
	buffer_write_tag(&w.buf, .Float)
	buffer_write_u16_be(&w.buf, u16(len(name)))
	buffer_write_string(&w.buf, name)
	buffer_write_f32_be(&w.buf, value)
}

writer_write_double :: proc(w: ^Writer, name: string, value: Double) {
	buffer_write_tag(&w.buf, .Double)
	buffer_write_u16_be(&w.buf, u16(len(name)))
	buffer_write_string(&w.buf, name)
	buffer_write_f64_be(&w.buf, value)
}

writer_write_byte_array :: proc(w: ^Writer, name: string, value: ByteArray) {
	buffer_write_tag(&w.buf, .ByteArray)
	buffer_write_u16_be(&w.buf, u16(len(name)))
	buffer_write_string(&w.buf, name)
	buffer_write_i32_be(&w.buf, i32(len(value)))
	for v in value {
		buffer_write_byte(&w.buf, byte(v))
	}
}

writer_write_int_array :: proc(w: ^Writer, name: string, value: IntArray) {
	buffer_write_tag(&w.buf, .IntArray)
	buffer_write_u16_be(&w.buf, u16(len(name)))
	buffer_write_string(&w.buf, name)
	buffer_write_i32_be(&w.buf, i32(len(value)))
	for v in value {
		buffer_write_i32_be(&w.buf, v)
	}
}

writer_write_long_array :: proc(w: ^Writer, name: string, value: LongArray) {
	buffer_write_tag(&w.buf, .LongArray)
	buffer_write_u16_be(&w.buf, u16(len(name)))
	buffer_write_string(&w.buf, name)
	buffer_write_i32_be(&w.buf, i32(len(value)))
	for v in value {
		buffer_write_i64_be(&w.buf, v)
	}
}

writer_write :: proc {
	writer_write_int,
	writer_write_byte,
	writer_write_short,
	writer_write_long,
	writer_write_float,
	writer_write_double,
	writer_write_compound,
	writer_write_byte_array,
	writer_write_int_array,
	writer_write_long_array,
}

writer_write_compound :: proc(w: ^Writer, value: any, name := "") {
	if value == nil {
		return
	}

	buffer_write_tag(&w.buf, .Compound)
	defer buffer_write_tag(&w.buf, .End)
	if name == "" {
		buffer_write_u16_be(&w.buf, u16(0))
	} else {
		buffer_write_u16_be(&w.buf, u16(len(name)))
		buffer_write_string(&w.buf, name)
	}

	ti := runtime.type_info_base(type_info_of(value.id))
	if ti == nil {
		return
	}

	#partial switch info in ti.variant {
	case runtime.Type_Info_Struct:
		writer_write_struct_fields(w, value.data, info)
	case:
		fmt.printfln("Unhandled type in writer_write_any_compound: %v", ti.id)
	}
}

writer_write_struct_fields :: proc(w: ^Writer, data: rawptr, struct_info: runtime.Type_Info_Struct) {
	fields_count := struct_info.field_count

	for field_index in 0..<fields_count {
		field_name := struct_info.names[field_index]
		field_type := struct_info.types[field_index]
		field_tag := struct_info.tags[field_index]
		field_offset := struct_info.offsets[field_index]

		if field_tag == "nbt:\"-\"" {
			continue
		}

		custom_name := field_name

		if strings.starts_with(field_tag, "nbt:\"") {
			end_quote := strings.last_index(field_tag, "\"")
			if end_quote > 5 {
				tag_content := field_tag[5:end_quote]
				if strings.contains(tag_content, ",") {
					parts := strings.split(tag_content, ",", context.allocator)
					custom_name = parts[0]
				} else {
					custom_name = tag_content
				}
			}
		}

		field_ptr := rawptr(uintptr(data) + uintptr(field_offset))
		field_value := any{field_ptr, field_type.id}

		writer_write_field(w, field_value, custom_name)
	}
}

writer_write_field :: proc(w: ^Writer, value: any, name: string) {
	if value.id == nil {
		return
	}

	ti := runtime.type_info_base(type_info_of(value.id))
	if ti == nil {
		return
	}

	#partial switch info in ti.variant {
	case runtime.Type_Info_Named:
		base_ti := runtime.type_info_base(info.base)
		if base_ti != nil {
			writer_write_field(w, any{value.data, base_ti.id}, name)
		}

	case runtime.Type_Info_Pointer:
		ptr_value := (^rawptr)(value.data)^
		if ptr_value == nil {
			return
		}

		elem_ti := runtime.type_info_base(info.elem)
		if elem_ti == nil {
			return
		}

		deref_value := any{ptr_value, elem_ti.id}
		writer_write_field(w, deref_value, name)

	case runtime.Type_Info_Struct:
		writer_write_compound(w, value, name)

	case runtime.Type_Info_Integer:
		switch ti.id {
		case byte:
			fmt.printfln("Warning: Unsigned byte %v may produce unexpected results, use i8 instead!", ti.id)
			v := (^byte)(value.data)^
			writer_write_byte(w, name, v)
		case i8:
			v := (^byte)(value.data)^
			writer_write_byte(w, name, v)
		case i16:
			v := (^i16)(value.data)^
			writer_write_short(w, name, v)
		case i32:
			v := (^i32)(value.data)^
			writer_write_int(w, name, v)
		case i64:
			v := (^i64)(value.data)^
			writer_write_long(w, name, v)
		case u8, u16, u32, u64:
			fmt.printfln("Warning: Unsigned integer %v may produce unexpected results!", ti.id)
			writer_write_int(w, name, i32((^i64)(value.data)^))
		}

	case runtime.Type_Info_Float:
		switch ti.id {
		case f32:
			v := (^f32)(value.data)^
			writer_write_float(w, name, v)
		case f64:
			v := (^f64)(value.data)^
			writer_write_double(w, name, v)
		}

	case runtime.Type_Info_String:
		v := (^string)(value.data)^
		writer_write_string(w, name, v)

	case runtime.Type_Info_Slice:
		elem_ti := runtime.type_info_base(info.elem)
		if elem_ti == nil {
			return
		}

		#partial switch elem_info in elem_ti.variant {
		case runtime.Type_Info_Integer:
			switch elem_ti.id {
			case i8:
				writer_write_byte_array(w, name, (^[]i8)(value.data)^)
			case i32:
				writer_write_int_array(w, name, (^[]i32)(value.data)^)
			case i64:
				writer_write_long_array(w, name, (^[]i64)(value.data)^)
			case:
				fmt.printfln("Unsupported integer slice type for NBT array: %v", elem_ti.id)
			}
		case:
			fmt.printfln("Unsupported slice element type for NBT array: %v", elem_ti.id)
		}

	case:
		fmt.printfln("Unhandled field type: %v", ti.id)
	}
}
