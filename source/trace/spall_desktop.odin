package trace

import "core:sync"
import "base:runtime"
import "core:prof/spall"

when ODIN_ARCH != .wasm32 {
	IS_TRACING :: false // enable this for tracing on desktop
} else {
	IS_TRACING :: false
}

when IS_TRACING {
	// Tracing stuff with spall
	// Generates a .spall file that can be loaded in https://gravitymoth.com/spall/spall.html
	// warning: the file sizes are huge. Only run for a few seconds if this is enabled

	spall_ctx: spall.Context
	@(thread_local)
	spall_buffer: spall.Buffer
	@(thread_local)
	spall_buffer_backing: []u8
	
	// Should be created at applcation start
	spall_context_create :: proc() {
		spall_ctx = spall.context_create("trace_test.spall")
	}

	spall_context_destroy :: proc() {
		spall.context_destroy(&spall_ctx)
	}

	// Should be created for each thread
	@(deferred_in=buffer_destroy)
	buffer_scoped :: proc() {
		buffer_create()
	}

	buffer_create :: proc() {
		spall_buffer_backing = make([]u8, spall.BUFFER_DEFAULT_SIZE)
		spall_buffer = spall.buffer_create(spall_buffer_backing, u32(sync.current_thread_id()))
	}

	buffer_destroy :: proc() {
		spall.buffer_destroy(&spall_ctx, &spall_buffer)
		delete(spall_buffer_backing)
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
}