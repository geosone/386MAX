# QEMU TCG plugin memwatch (needs QEMU built with plugin support and its
# qemu-plugin.h, e.g. Gentoo USE=plugins)
memwatch.so: memwatch.c
	$(CC) -O2 -Wall -shared -fPIC $$(pkg-config --cflags glib-2.0) -o $@ $<
clean:
	rm -f memwatch.so
