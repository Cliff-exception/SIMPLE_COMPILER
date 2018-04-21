%{
#include <stdio.h>
#include "attr.h"
#include "instrutil.h"
int yylex();
void yyerror(char * s);
#include "symtab.h"

FILE *outfile;
char *CommentBuffer;

 
%}

%union {tokentype token;
        regInfo targetReg;
        tokNode * head; 
        Stype_struct s_type;  
        label_list * l_list; 
       }

%token PROG PERIOD VAR 
%token INT BOOL PRINT THEN IF DO  
%token ARRAY OF 
%token BEG END ASG  
%token EQ NEQ LT LEQ GT GEQ AND OR TRUE FALSE
%token ELSE
%token WHILE 
%token <token> ID ICONST 

%type <targetReg> exp 
%type <targetReg> lhs  condexp
%type <head>      idlist
%type <s_type>    type stype
%type <l_list>    WHILE ifhead

%start program

%nonassoc EQ NEQ LT LEQ GT GEQ 
%left '+' '-' AND
%left '*' OR

%nonassoc THEN
%nonassoc ELSE

%%
program : {emitComment("Assign STATIC_AREA_ADDRESS to register \"r0\"");
           emit(NOLABEL, LOADI, STATIC_AREA_ADDRESS, 0, EMPTY);} 
           PROG ID ';' block PERIOD { }
	;

block	: variables cmpdstmt { }
	;

variables: /* empty */
	| VAR vardcls { }
	;

vardcls	: vardcls vardcl ';' { }
	| vardcl ';' { }
	| error ';' { yyerror("***Error: illegal variable declaration\n");}  
	;

vardcl	: idlist ':' type { tokNode * ptr = $1;

			    while ( ptr != NULL ) {
			    			     
			     int offset = NextOffset($3.size); 
			     
			     insert(ptr->tok, $3.type, offset );
			      
			     ptr = ptr->next; 
			    
			    }
 			    
  }
	;

idlist	: idlist ',' ID { tokNode * ptr = $$; 

			  while ( ptr->next != NULL )
				ptr = ptr->next; 
				
			tokNode * temp = (tokNode*)malloc(sizeof(tokNode)); 
			temp->tok = (char*)malloc(sizeof(char) * 10); 
			strcpy(temp->tok, $3.str); 
			
			ptr->next = temp; 
			temp->next = NULL; 
   }
        | ID		{ $$ = (tokNode*)malloc(sizeof(tokNode));   
       			  $$->tok = (char*)malloc(sizeof(char)*10);
       		          strcpy($$->tok, $1.str);
       		          $$->next = NULL;  
        } 
	;


type	: ARRAY '[' ICONST ']' OF stype {  
	  //assign the type
	  $$.type = $6.type; 
	  $$.size = $3.num;
}

        | stype { $$.type = $1.type; 
        	  $$.size = 1; 
         }
	;

stype	: INT { $$.type = TYPE_INT;  }
        | BOOL { $$.type = TYPE_BOOL;}
	;

stmtlist : stmtlist ';' stmt { }
	| stmt { }
        | error { yyerror("***Error: ';' expected or illegal statement \n");}
	;
/* ignore */
stmt    : ifstmt { }
	| wstmt { }
	| astmt { }
	| writestmt { }
	| cmpdstmt { }
	;
/* omit */ 
cmpdstmt: BEG stmtlist END { }
	;

ifstmt :  ifhead 
          THEN stmt {
           emit(NOLABEL, BR, $1->label_3, EMPTY, EMPTY); 
           emit($1->label_2, NOP, EMPTY, EMPTY, EMPTY); 
           
          }
          
  	  ELSE 
          stmt {
          
           emit($1->label_3, NOP, EMPTY, EMPTY, EMPTY); 
          
          }
	;

ifhead : IF condexp { 
	 $$ = (label_list*)malloc(sizeof(label_list)); 
	 int label = NextLabel();  
	 int label2 = NextLabel(); 
	 int label3 = NextLabel(); 
	 $$->label_1 = label; 
	 $$->label_2 = label2; 
	 $$->label_3 = label3; 
	 emit(NOLABEL, CBR, $2.targetRegister, label, label2);
	 emit($$->label_1, NOP, EMPTY, EMPTY, EMPTY); 	 
	 }	
        ;

writestmt: PRINT '(' exp ')' { int printOffset = -4; /* default location for printing */
  	                         sprintf(CommentBuffer, "Code for \"PRINT\" from offset %d", printOffset);
	                           emitComment(CommentBuffer);
                                 emit(NOLABEL, STOREAI, $3.targetRegister, 0, printOffset);
                                 emit(NOLABEL, 
                                      OUTPUTAI, 
                                      0,
                                      printOffset, 
                                      EMPTY);
                               }
	;

wstmt	: WHILE  {  
                    $1 = (label_list*)malloc(sizeof(label_list)); 
		    int label = NextLabel(); 
		    $1->label_1 = label; 
		    emit( label, NOP, EMPTY, EMPTY, EMPTY );
		    
		    label = NextLabel(); 
		    int label2 = NextLabel(); 
		    $1->label_2 = label;
		    $1->label_3 = label2; 
		    
  } 
          condexp {
      		     
      		    emit(NOLABEL, CBR, $3.targetRegister, $1->label_2, $1->label_3);
      		    emitComment("\n");
      		    emit($1->label_2, NOP, EMPTY, EMPTY, EMPTY);
          
            } 
          
          DO stmt { 
                   emit($1->label_1, BR, EMPTY, EMPTY, EMPTY); 
                   emitComment("\n"); 
                   emit($1->label_3, NOP, EMPTY, EMPTY, EMPTY); 
               
            } 
	;


astmt : lhs ASG exp             { 
 				  if (! ((($1.type == TYPE_INT) && ($3.type == TYPE_INT)) || 
				         (($1.type == TYPE_BOOL) && ($3.type == TYPE_BOOL)))) {
				    printf("*** ERROR ***: Assignment types do not match.\n");
				  }

				  emit(NOLABEL,
                                       STORE, 
                                       $3.targetRegister,
                                       $1.targetRegister,
                                       EMPTY);
                                }
	;

lhs	: ID			{ 
                                  int newReg1 = NextRegister();
                                  int newReg2 = NextRegister();
                                  SymTabEntry * entry = lookup($1.str); 
                                  int offset = entry->offset; 
				  
                                  $$.targetRegister = newReg2;
                                  $$.type = entry->type; 
				   
				  emit(NOLABEL, LOADI, offset, newReg1, EMPTY);
				  emit(NOLABEL, ADD, 0, newReg1, newReg2);
				  
                         	  }


                                |  ID '[' exp ']' {   
                                
                                	//SymTabEntry * entry = lookup ( $1.str); 
                                	
                                	
                                       // check some errors 
                                       
                                       int reg1 = NextRegister(); 
                                       int reg2 = NextRegister(); 
                                       int reg3 = NextRegister(); 
                                       int reg4 = NextRegister(); 
                                       int reg5 = NextRegister(); 
                                       int num = entry->offset; 
                                       
                                       printf("Offset: %d \n", num ); 
                                       
                                       emit(NOLABEL, LOADI,4,reg1, EMPTY);
                                       
                                       emit(NOLABEL, MULT, reg1, $3.targetRegister, reg2);
                                       
                                       emit(NOLABEL, LOADI, num, reg3, EMPTY);  
                                        
                                       emit(NOLABEL, ADD, reg2, reg3, reg4);
                                        
                                       emit(NOLABEL, ADD, 0, reg4, reg5);
                                       
                                       $$.targetRegister = reg5;  
                                
                                }
                                ;


exp	: exp '+' exp		{ int newReg = NextRegister();

                                  if (! (($1.type == TYPE_INT) && ($3.type == TYPE_INT))) {
    				    printf("*** ERROR ***: Operator types must be integer.\n");
                                  }
                                  $$.type = $1.type;

                                  $$.targetRegister = newReg;
                                  emit(NOLABEL, 
                                       ADD, 
                                       $1.targetRegister, 
                                       $3.targetRegister, 
                                       newReg);
                                }

        | exp '-' exp		{ int newReg = NextRegister();

                                  if ( ! (($1.type == TYPE_INT) && ($3.type == TYPE_INT))) {
                                    printf("*** ERROR ***: Operand type must be integer\n");
                                  }

                                  $$.type = $1.type;

                                  $$.targetRegister = newReg; 

                                  emit(NOLABEL, SUB, $1.targetRegister, $3.targetRegister, newReg);       
        
        }
        
        

        | exp '*' exp		{ int newReg = NextRegister(); 

                                  if ( !(($1.type == TYPE_INT ) && ( $3.type == TYPE_INT ))) {

                                      printf("*** ERROR ***: Operand type must be integer\n");
                                  }

                                  $$.type = $1.type; 
                                  $$.targetRegister = newReg; 

                                  emit(NOLABEL, MULT, $1.targetRegister, $3.targetRegister, newReg); 
        
        
        }

        | exp AND exp		{ int newReg = NextRegister(); 

                                  if ( !(( $1.type == TYPE_BOOL ) && ($3.type == TYPE_BOOL)) ) {

                                      printf("*** ERROR ***: Operand type must be boolean \n");
                                  }

                                  $$.type = $1.type; 
                                  $$.targetRegister = newReg; 

                                  emit(NOLABEL, AND_INSTR, $1.targetRegister, $3.targetRegister, newReg); 
        
        
        
        } 


        | exp OR exp       	{   int newReg = NextRegister(); 

                                    if ( !(( $1.type == TYPE_BOOL ) && ( $3.type == TYPE_BOOL)) ) {

                                        printf("*** ERROR ****: Operand type must be boolean\n");
                                    }

                                    $$.type = $1.type; 
                                    $$.targetRegister = newReg; 

                                    emit(NOLABEL, OR_INSTR, $1.targetRegister, $3.targetRegister, newReg); 
        
        
        
        
        }


        | ID			{
	                          int newReg = NextRegister();
                                  SymTabEntry * entry  = lookup($1.str); 
                                  int offset = entry->offset;  

	                          $$.targetRegister = newReg;
				  $$.type = entry->type;
				  emit(NOLABEL, LOADAI, 0, offset, newReg);
                                  
	                        }

        | ID '[' exp ']'	{   }
 


	| ICONST                 { int newReg = NextRegister();
	                           $$.targetRegister = newReg;
				   $$.type = TYPE_INT;
				   emit(NOLABEL, LOADI, $1.num, newReg, EMPTY); }

        | TRUE                   { int newReg = NextRegister(); /* TRUE is encoded as value '1' */
	                           $$.targetRegister = newReg;
				   $$.type = TYPE_BOOL;
				   emit(NOLABEL, LOADI, 1, newReg, EMPTY); }

        | FALSE                   { int newReg = NextRegister(); /* TRUE is encoded as value '0' */
	                           $$.targetRegister = newReg;
				   $$.type = TYPE_BOOL;
				   emit(NOLABEL, LOADI, 0, newReg, EMPTY); }

	| error { yyerror("***Error: illegal expression\n");}  
	;


condexp	: exp NEQ exp		{  

					int newReg = NextRegister(); 
					
					if( $1.type != $3.type) {
					
						printf("\n*** ERROR ***: == or != operator with different types.\n"); 	
												    
					}
					
					$$.targetRegister = newReg; 
					$$.type = $1.type; 
					
					emit(NOLABEL, CMPNE, $1.targetRegister, $3.targetRegister, newReg); 
} 

        | exp EQ exp		{  
 					int newReg = NextRegister(); 
					
					if( $1.type != $3.type ) {
					
						printf("\n*** ERROR ***: == or != operator with different types.\n"); 	
												    
					}
					
					$$.targetRegister = newReg; 
					$$.type = $1.type; 
					
					emit(NOLABEL, CMPEQ, $1.targetRegister, $3.targetRegister, newReg);        				
        				
        
        } 

        | exp LT exp		{  
 					int newReg = NextRegister(); 
					
					if( !(( $1.type == TYPE_INT) && ( $3.type == TYPE_INT )) ) {
					
						printf("\n*** ERROR ***: Relational operator with illegal type.\n"); 
												    
					}
					
					$$.targetRegister = newReg; 
					$$.type = $1.type; 
					
					emit(NOLABEL, CMPLT, $1.targetRegister, $3.targetRegister, newReg);        				
        				        
        
        
        }

        | exp LEQ exp		{  
  					int newReg = NextRegister(); 
					
					if(!(( $1.type == TYPE_INT) && ( $3.type == TYPE_INT )) ) {
					
						printf("\n*** ERROR ***: Relational operator with illegal type.\n"); 
												    
					}
					
					$$.targetRegister = newReg; 
					$$.type = $1.type; 
					
					emit(NOLABEL, CMPLE, $1.targetRegister, $3.targetRegister, newReg);        				
        				       
        
        
        }

	| exp GT exp		{ 
 					int newReg = NextRegister(); 
					
					if(!(( $1.type == TYPE_INT) && ( $3.type == TYPE_INT )) ) {
					
						printf("\n*** ERROR ***: Relational operator with illegal type.\n"); 	
												    
					}
					
					$$.targetRegister = newReg; 
					$$.type = $1.type; 
					
					emit(NOLABEL, CMPGT, $1.targetRegister, $3.targetRegister, newReg);        				
        					
	
	
	 }

	| exp GEQ exp		{ 
 					int newReg = NextRegister(); 
					
					if( !(( $1.type == TYPE_BOOL ) && ($3.type == TYPE_BOOL)) || !(( $1.type == TYPE_INT) && ( $3.type == TYPE_INT )) ) {
					
						printf("\n*** ERROR ***: Relational operator with illegal type.\n");  	
												    
					}
					
					$$.targetRegister = newReg; 
					$$.type = $1.type; 
					
					emit(NOLABEL, CMPGE, $1.targetRegister, $3.targetRegister, newReg);        				
        					
	
	
	 }

	| error { yyerror("***Error: illegal conditional expression\n");}  
        ;

%%

void yyerror(char* s) {
        fprintf(stderr,"%s\n",s);
        }


int
main(int argc, char* argv[]) {

  printf("\n     CS415 Spring 2018 Compiler\n\n");

  outfile = fopen("iloc.out", "w");
  if (outfile == NULL) { 
    printf("ERROR: cannot open output file \"iloc.out\".\n");
    return -1;
  }

  CommentBuffer = (char *) malloc(650);  
  InitSymbolTable();

  printf("1\t");
  yyparse();
  printf("\n");

  PrintSymbolTable();
  
  fclose(outfile);
  
  return 1;
}




