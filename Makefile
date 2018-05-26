NAME = fighter_parser
TEST = jsevents.txt

all: clean js compile run

js:	js.c
	gcc -o js js.c -pthread

scanner:
	flex $(NAME).l
	gcc lex.yy.c $(NAME).c -lfl

compile: $(NAME).l $(NAME).y
	flex $(NAME).l
	bison  $(NAME).y -yd
	gcc -o $(NAME) lex.yy.c y.tab.c $(NAME).c -lfl -ly -pthread

clean:
	rm lex.yy.c y.tab.h y.tab.c $(NAME) js

run:
	./$(NAME) < $(TEST)
