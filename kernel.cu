#include<cuda_runtime.h>
#include<stdio.h>
#include<conio.h>
#include<string.h>
#include<iostream>

using namespace std;

//The concept is to make a programmable program. Hence the use of these pointers below.
char** name;
double** doubleData;
double*** doubleListData;
int** intData;
int*** intListData;
char** charData;
char*** charListData;
int** boolData;
int*** boolListData;

//How many blocks of each the meta program needs.
int DoubleQuantity,DoubleListX,DoubleListY,IntQuantity,IntListX, IntListY,CharQuantity, CharListX, CharListY, BoolQuantity,BoolListX,BoolListY;

//Total entities in the simulation. 
int total;

//Initializer for the simulation. Creates memory spaces in accordance with the total no. of entities. Uses UVA, hence always use x64. 
int setTotal(int Total){
	total = Total;

	cudaMallocHost((void**)&name, total * sizeof(char*));
	cudaMallocHost((void**)&doubleData, total * sizeof(double*));
	cudaMallocHost((void**)&doubleListData, total * sizeof(double**));
	cudaMallocHost((void**)&intData, total * sizeof(int*));
	cudaMallocHost((void**)&intListData, total * sizeof(int**));
	cudaMallocHost((void**)&charData, total * sizeof(char*));
	cudaMallocHost((void**)&charListData, total * sizeof(char**));
	cudaMallocHost((void**)&boolData, total * sizeof(int*));
	cudaMallocHost((void**)&boolListData, total * sizeof(int**));

	return 1;
}

//Now that the memory spaces are allocated. The meta program memory requirements are taken care of. That is, the memory the program from java needs. 
int setEntity(char* Name,int doubleQuantity, int doubleListX, int doubleListY,
	int intQuantity, int intListX, int intListY,
	int charQuantity, int charListX, int charListY,
	int boolQuantity, int boolListX, int boolListY){
	//This function is called for every entity to be placed and allocated. If you want 1600 enitites. You call this 1600 times. Hence the static index.
	static int index = 0;
	if (index < total){

		cudaMallocHost((void**)&name[index], strlen(Name) * sizeof(char));
		strcpy(name[index],Name);
		if (doubleQuantity > 0)
			cudaMallocHost((void**)&doubleData[index], doubleQuantity*sizeof(double));
		if (doubleListY > 0){
			cudaMallocHost((void**)&doubleListData[index], doubleListY * sizeof(double*));
			for (int i = 0; i < doubleListY; i++)
				cudaMallocHost((void**)&doubleListData[index][i], doubleListX * sizeof(double));
		}

		if (intQuantity > 0)
			cudaMallocHost((void**)&intData[index], intQuantity*sizeof(int));
		if (intListY > 0){
			cudaMallocHost((void**)&intListData[index], intListY * sizeof(int*));
			for (int i = 0; i < intListY; i++)
				cudaMallocHost((void**)&intListData[index][i], intListX * sizeof(int));
		}

		if (charQuantity > 0)
			cudaMallocHost((void**)&charData[index], charQuantity*sizeof(char));
		if (charListY > 0){
			cudaMallocHost((void**)&charListData[index], charListY * sizeof(char*));
			for (int i = 0; i < charListY; i++)
				cudaMallocHost((void**)&charListData[index][i], charListX * sizeof(char));
		}

		if (boolQuantity > 0)
			cudaMallocHost((void**)&boolData[index], boolQuantity*sizeof(int));
		if (boolListY > 0){
			cudaMallocHost((void**)&boolListData[index], boolListY * sizeof(int*));
			for (int i = 0; i < boolListY; i++)
				cudaMallocHost((void**)&boolListData[index][i], boolListX * sizeof(int));
		}
	}
	
	index++;
	return 1;
}

//function pointer for functions modifying doubleData
typedef void(*modifierDouble)(double* array, int index, double operand);

__device__ int strcmp(const char *s1, const char *s2)
{
	for (; *s1 == *s2; s1++, s2++)
		if (*s1 == '\0')
			return 0;
	return ((*(unsigned char *)s1 < *(unsigned char *)s2) ? -1 : +1);
}

/////////////////////////////////////////////////////////////////Double Section


__device__ void addDouble(double* array, int index, double operand){
	array[index] += operand;
}

__device__ void subDouble(double* array, int index, double operand){
	array[index] -= operand;
}

__device__ void mulDouble(double* array, int index, double operand){
	array[index] *= operand;
}

__device__ void divDouble(double* array, int index, double operand){
	array[index] /= operand;
}
__device__ modifierDouble io_addDouble = addDouble;
__device__ modifierDouble io_subDouble = subDouble;
__device__ modifierDouble io_mulDouble = mulDouble;
__device__ modifierDouble io_divDouble = divDouble;

void initDoubleFunctions(modifierDouble* io_modifierDouble){
	cudaMemcpyFromSymbol(&io_modifierDouble[0], io_addDouble, sizeof(modifierDouble));
	cudaMemcpyFromSymbol(&io_modifierDouble[1], io_subDouble, sizeof(modifierDouble));
	cudaMemcpyFromSymbol(&io_modifierDouble[2], io_mulDouble, sizeof(modifierDouble));
	cudaMemcpyFromSymbol(&io_modifierDouble[3], io_divDouble, sizeof(modifierDouble));
}
/////////////////////////////////////////////////////////////Int Section
__device__ void addInt(int* array, int index, int operand){
	array[index] += operand;
}

__device__ void subInt(int* array, int index, int operand){
	array[index] -= operand;
}

__device__ void mulInt(int* array, int index, int operand){
	array[index] *= operand;
}

__device__ void divInt(int* array, int index, int operand){
	array[index] /= operand;
}

/*
This is the function. I mean, THE function. It simulates and does the core job. For it, the pointers declared on top are required and an instruction set.
The instruction set is what makes this code programmble. Here's the legend for the instruction set:
1)io_name - Name of the Entity
2)io_morphCode - an integer which tells which data structure to modify(doubleData/intData/...)
3)io_functionCode - an integer which tells which function to apply and use(0 means add)
4)io_index1 - an index to the memory of the data structure chosen by io_morphCode. Signifies which trait of the entity to modify.
5)io_index2 - same as io_index1 but for 2D arrays.
6)io_operand - the operand for the function operation.
7)isMemory - tells if the operand lies in the memory or not and if does then which data structure it lies in.
8)entityIndex - The entity whose memory should be used as operand
8)memIndices - the address of that memory operand
*/
__global__ void ultimateCoder(
	char** name,double** doubleData,int** intData,
	char* io_name, int io_morphCode, int io_functionCode, int io_index1, int io_index2, double io_operand, int isMemory, int entityIndex, int memIndex1, int memIndex2,
	modifierDouble* io_modierDouble){
	
	int index = threadIdx.x + blockIdx.x * blockDim.x;
	if (!strcmp(io_name, name[index])){
		switch (io_morphCode){
		case 0://Double
			switch (isMemory)
			{
			case 0:
				break;
			case 1://operand from Int
				io_operand = intData[entityIndex][memIndex1];
				break;
			case 2://operand from IntList
				//io_operand = intListData[entityIndex][memIndex1][memIndex2];
				break;
			case 3://operand from Double
				io_operand = doubleData[entityIndex][memIndex1];
				break;
			case 4://operand from DoubleList
				//io_operand = doubleListData[entityIndex][memIndex1][memIndex2];
				break;
			}
			io_modierDouble[io_functionCode](doubleData[index], io_index1, io_operand);
			break;
		}
	}

}

int main(){
	setTotal(2);
	setEntity("yay",1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1);
	setEntity("yay2",1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1);
	doubleData[0][0]= 19;
	modifierDouble* io_modifierDouble;
	cudaMallocHost((void**)&io_modifierDouble, 4 * sizeof(modifierDouble));
	initDoubleFunctions(io_modifierDouble);
	char* na;
	cudaMallocHost((void**)&na, 3 * sizeof(char));
	strcpy(na, "yay2");
	ultimateCoder <<<1,2>>> (name, doubleData, intData, na, 0, 0, 0, 0, 0, 3, 0, 0, 0, io_modifierDouble);
	cudaDeviceSynchronize();
	strcpy(na, "yay");
	ultimateCoder <<<1,2>>> (name, doubleData, intData, na, 0, 1, 0, 0, 3, 0, 0, 0, 0, io_modifierDouble);
	cudaDeviceSynchronize();
	printf("%f %f", doubleData[1][0], doubleData[0][0]);
	getch();
}