#+build !wasm32
package trace

import "core:sync"
import "base:runtime"
import "core:prof/spall"

_instrumentation :: false

when _instrumentation {
	// Tracing stuff with spall
	// Generates a .spall file that can be loaded in https://gravitymoth.com/spall/spall.html
	// IMPROV add conditional compile

	spall_ctx: spall.Context
	@(thread_local)
	spall_buffer: spall.Buffer
	spall_buffer_backing: []u8

	spall_init :: proc() {
		spall_ctx = spall.context_create("trace_test.spall")
		spall_buffer_backing = make([]u8, spall.BUFFER_DEFAULT_SIZE)
		spall_buffer = spall.buffer_create(spall_buffer_backing, u32(sync.current_thread_id()))
		spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
	}

	spall_destroy :: proc() {
		defer spall.context_destroy(&spall_ctx)
		defer delete(spall_buffer_backing)
		defer spall.buffer_destroy(&spall_ctx, &spall_buffer)
	}

	// Automatic profiling of every procedure:

	@(instrumentation_enter)
	spall_enter :: proc "contextless" (
		proc_address, call_site_return_address: rawptr,
		loc: runtime.Source_Code_Location,
	) {
		spall._buffer_begin(&spall_ctx, &spall_buffer, "", "", loc)
	}

	@(instrumentation_exit)
	spall_exit :: proc "contextless" (
		proc_address, call_site_return_address: rawptr,
		loc: runtime.Source_Code_Location,
	) {
		spall._buffer_end(&spall_ctx, &spall_buffer)
	}
} else {
	spall_init :: proc() {}
	spall_destroy :: proc() {}
}
