CC=gcc
CFLAGS=-std=c99 

all: mini 

mini: mini.o 
	$(CC) $(CFLAGS) -o $@ $^

mini.o: mini.c 

clean: 
	$(RM) one_to_ten *.o
