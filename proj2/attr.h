/**********************************************
        CS415  Project 2
        Spring  2015
        Student Version
**********************************************/

#ifndef ATTR_H
#define ATTR_H

typedef union {int num; char *str;} tokentype;

typedef enum type_expression {TYPE_INT=0, TYPE_BOOL, TYPE_ERROR} Type_Expression;

typedef struct {
        Type_Expression type;
        int targetRegister;
        } regInfo;
        
typedef struct {
      Type_Expression type; 
      int size; 
} Stype_struct; 
        
        
typedef struct regNode {
 
    char * tok; 
    struct regNode * next;
    
}tokNode;

typedef struct label {
  
   int label_1; 
   int label_2; 
   int label_3; 
} label_list; 

/*typedef struct TokList{

    regNode * head; 
    regNode * tail;

}TokenList;*/


#endif


  
