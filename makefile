.PHONY: clean

clean:
	rm -f *.o main
brambench: brambench.o
	g++ -o brambench brambench.o
	./brambench