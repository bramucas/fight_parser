%{

#include "y.tab.h"
#include "fighter_parser.h"

%}

ButtonA Button" "A" "pressed
ButtonB Button" "B" "pressed
ButtonX Button" "X" "pressed
ButtonY Button" "Y" "pressed
ButtonS Button" "S" "pressed

LeaveA Button" "A" "released
LeaveB Button" "B" "released
LeaveX Button" "X" "released
LeaveY Button" "Y" "released
LeaveS Button" "S" "released

Time T[0-9]+"."[0-9]+

Nothing nothing

Axis	Axis" "0" "at" ""("

Coord	-?[0-9]+

%%

{Time}		{yylval.time = atof(strReplace("T", "", yytext));}

{ButtonA}	{return A;}
{ButtonB}	{return B;}
{ButtonX}	{return X;}
{ButtonY}	{return Y;}
{ButtonS}	{return S;}

{LeaveA}	{return LA;}
{LeaveB}	{return LB;}
{LeaveX}	{return LX;}
{LeaveY}	{return LY;}
{LeaveS}	{return LS;}

{Nothing}	{return NA;}

{Axis}		{}
{Coord}		{
	 			switch (handleAxisCoord(atoi(yytext)))
		 		{
		 			case 1:
		 				return UP;
		 				break;
		 			case 2:
		 				return UP_RIGHT;
		 				break;
		 			case 3:
		 				return RIGHT;
		 				break;
		 			case 4:
		 				return DOWN_RIGHT;
		 				break;
		 			case 5:
		 				return DOWN;
		 				break;
		 			case 6:
		 				return DOWN_LEFT;
		 				break;
		 			case 7:
		 				return LEFT;
		 				break;
		 			case 8:
		 				return UP_LEFT;
		 				break;
		 			default:
		 				break;
		 		};
			}

" "		{}
\n		{}
.       {}
%%
