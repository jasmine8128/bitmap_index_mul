#include<stdio.h>
#include<math.h>
#include<stdlib.h>
#define CHECK(res) if (res!=cudaSuccess){exit(-1);}	//check if success
const int height=10;		//the kinds of attributes(>=)
const int width=100;		//the kinds of datas(>=)
const int kinds=30;			//the kinds of types(>=)
const int bit_size=width*height*sizeof(int );	//the size of bitat[][]
const int index_size=width*sizeof(int );
unsigned int bit[height][width];
unsigned int bitat[width][height];	//add 0-Fill data
int key[height][kinds];
int offset[height][kinds];
int index_bit[width];
int index_long[1];
int attr_size;				//the kinds of attributes(=)
int attr_total;				//the kinds of datas/31 (=)
unsigned int bin_31=0x80000000;
FILE *fp;
char str[33];
cudaError_t res;

void my_itoa(int num,char *strr,int bin2)	//change num(decimal) into strr(binary)
{
    int i;
    int b=0x00000001;
    for(i=31;i>=0;i--)
    {
        if(num&b)
            strr[i]='1';
        else
            strr[i]='0';
        num=num>>1;
    }
    strr[32]='\0';
}

void get_attr_size()	//get attr_size
{
	fp=fopen("outputm.txt","r");
	char c;
	attr_size=0;
	while((c=fgetc(fp))!=EOF)
	{
		if(c=='[')
			attr_size++;

	}
	attr_size=attr_size/2;
	fclose(fp);
}
void get_bitmap()  //get bitmap,key and offset from file
{
	fp=fopen("outputm.txt","r");
	int i,j,k,offs;
	char init;
	i=0;j=0;k=0;
	fscanf(fp,"%d",&bit[i][j]);j++;
	while((init=fgetc(fp))!=EOF)
	{
		if(init=='[')
		{
			fscanf(fp,"%d",&offs);
			while(fgetc(fp)!=']')
			{
				key[i][k]=offs;k++;
				fscanf(fp,"%d",&offs);
			}
			key[i][k]=offs;
			while(fgetc(fp)!='[');k=0;
			fscanf(fp,"%d",&offs);
			while(fgetc(fp)!=']')
			{
				offset[i][k]=offs;k++;
				fscanf(fp,"%d",&offs);
			}
			offset[i][k]=offs;
			i++;j=0;k=0;
		}
		else{
			fscanf(fp,"%d",&bit[i][j]);
			j++;
		}
	}
}

void get_total()
{
	int i,tsize,tlie;
	attr_total=0;
	tsize=key[0][0];
	tlie=offset[0][0];
	for(i=0;i<tsize;i++)
	{
		attr_total++;
		if(bit[0][tlie+i]<=bin_31)
			attr_total=attr_total+bit[0][tlie+i]-1;
	}
	printf("attr_total:%d\n",attr_total);

}
void get_attr() //get attr from screen,store them in the bitat[][]
{
	int i,j,k,attr;
	int size[height];
	int lie[height];
	int local;
	index_long[0]=0;
	for(i=0;i<attr_total;i++)
	{
		for(j=0;j<attr_size;j++)
			bitat[i][j]=0xffffffff;
	}
	for(i=0;i<attr_size;i++)
	{
		printf("Please input the attribute you choose(if not,input -1):\n");
		scanf("%d",&attr);
		if(attr==-1)
		{
			size[i]=0;
			lie[i]=0;
		}
		else{
			size[i]=key[i][attr];  //find key and offset
			lie[i]=offset[i][attr];
		}
	}
	for(i=0;i<attr_size;i++)		//store bitmap in the bitat[][]
	{
		local=-1;
		for(j=0;j<size[i];j++)
		{
			local+=1;
			if(bit[i][lie[i]+j]>bin_31)	//not 0-Fill
			{
				bitat[local][i]=bit[i][lie[i]+j];
			}
			else						//0-Fill
			{
				for(k=0;k<bit[i][lie[i]+j];k++)
				{
					bitat[local+k][i]=0;
				}
				local=local+bit[i][lie[i]+j]-1;
			}
		}
	}

}
__device__ void d_itoa(int num,char *strr)	//device change num(decimal) into strr(binary)
{
    int i;
    int b=0x00000001;
    for(i=31;i>=0;i--)
    {
        if(num&b)
            strr[i]='1';
        else
            strr[i]='0';
        num=num>>1;
    }
    strr[32]='\0';
}
__global__ void kernel_index_bitmap(unsigned int **dbit,int *dindex_bit,int *dindex_long,int dtotal,int dsize,int dheight,int dmul)
{
	int i,j,k,addr;
	char strr[33];
	unsigned int num;
	int idx=threadIdx.x+blockIdx.x*blockDim.x;
	int idy;
	int *add=(int *)((int *)dbit);		//the address of the bitat[][]
	for(i=0;i<dmul;i++)
	{
		idy=dmul*idx+i;
		num=0xffffffff;					//num=32 bits of '1'
		if(idy<dtotal)
		{
			for(j=0;j<dsize;j++)
			{
				num&=add[idy*dheight+j];
				printf("(%d,%d):%d\n",idy,idy*dheight+j,add[idy*dheight+j]);
			}
			printf("num:(%d,%d):%d\n",idx,idy*dheight+j,num);
			d_itoa(num,strr);
			printf("%d:%s\n",idy,strr);
			for(j=1;j<32;j++)
			{
				if(strr[j]=='1')
				{
					addr=idy*31+j;
					printf("attr:%d\n",addr);
					k=atomicAdd(&(dindex_long[0]),1);
					dindex_bit[k]=addr;
					printf("%d:%d\n",k,dindex_bit[k]);
				}
			}
		}
	}
}

void cuda_malloc_cpy()
{
	int i,j,mul;
	int thread_size=3;
	int block_size=1;
	mul=(attr_total+(thread_size*block_size-1))/(thread_size*block_size);//distribution of number of tasks
	printf("mul:%d\n",mul);
	int *dindex_bit;
	int *dindex_long;
	unsigned int **dbit;
	int a[width][height];//test
	for(i=0;i<width;i++)
	{
		for(j=0;j<height;j++)
		{
			a[i][j]=0;
		}
	}
	res=cudaMalloc((void **)&dindex_bit,index_size);CHECK(res);printf("\n[0] \n");
	res=cudaMalloc((void **)&dindex_long,sizeof(int ));CHECK(res);printf("[1] \n");
	res=cudaMalloc((void **)&dbit,bit_size);CHECK(res);printf("[2] \n");
	res=cudaMemcpy(dbit,bitat,bit_size,cudaMemcpyHostToDevice);CHECK(res);printf("[3] \n");
	res=cudaMemcpy(dindex_long,index_long,sizeof(int ),cudaMemcpyHostToDevice);CHECK(res);printf("[4] \n");
	dim3 threads(thread_size,1);
	dim3 blocks(block_size,1);
	kernel_index_bitmap<<<blocks,threads>>>(dbit,dindex_bit,dindex_long,attr_total,attr_size,height,mul);
	printf("---------------T_T-------------\n");
	res=cudaMemcpy(index_bit,dindex_bit,index_size,cudaMemcpyDeviceToHost);CHECK(res);printf("[5] \n");
	res=cudaMemcpy(index_long,dindex_long,sizeof(int ),cudaMemcpyDeviceToHost);CHECK(res);printf("[6] \n");
	res=cudaMemcpy(a,dbit,bit_size,cudaMemcpyDeviceToHost);CHECK(res);printf("[7] \n");
	printf("long:%d\n",index_long[0]);
	for(i=0;i<index_long[0];i++)
		printf("%d,",index_bit[i]);
	printf("\n");
	for(i=0;i<attr_total;i++)
	{
		for(j=0;j<attr_size;j++)
		{
			printf("%d,",a[i][j]);
		}
		printf("\n");
	}
	cudaFree(dbit);

}

int main()
{
	get_attr_size();
	get_bitmap();
	get_total();
	get_attr();
	cuda_malloc_cpy();

	return 0;
}
