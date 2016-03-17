#include<stdio.h>
#define CHECK(res) if(res!=cudaSuccess){exit(-1);}
const int width=5;
const int height=22;
const int size=width*height*sizeof(int );
//const int size=sizeof(int)*width;

/*__global__ void kerneltest(int **b,size_t pitch)
{
	printf("(%d,%d)\n",threadIdx.x,threadIdx.y);
	int *c=(int *)((char *)b+threadIdx.x*pitch);
	printf("%d, ",c[threadIdx.y]);
}

int main(int argc,char **argv)
{
	int i,j;
	int a[height][width];
	int c[height][width];
	int **b;
	size_t pitch;
	cudaError_t res;
	for(i=0;i<height;i++)
	{
		for(j=0;j<width;j++)
		{
			a[i][j]=j+i*width;
			c[i][j]=0;
			printf("%d  ",a[i][j]);
		}
		printf("\n");
	}
	res=cudaMallocPitch((void **)&b,&pitch,size,height);CHECK(res);printf("1");
	res=cudaMemcpy2D(b,pitch,a,size,size,height,cudaMemcpyHostToDevice);CHECK(res);printf("2");
	dim3 threads(5,10);
	dim3 blocks(1,1);
	kerneltest<<<blocks,threads>>>(b,pitch);
	printf("3");
	res=cudaMemcpy2D(c,size,b,pitch,size,height,cudaMemcpyDeviceToHost);CHECK(res);printf("4\n");
	for(i=0;i<height;i++)
	{
		for(j=0;j<width;j++)
		{
			printf("%d  ",c[i][j]);
		}
		printf("\n");
	}
	cudaFree(b);
	return 0;
}
*/
__global__ void testkernel(int **b,int dheight,int dwidth,int dmul)
{
	//printf("%d\n",add[threadIdx.x+blockIdx.x*blockDim.x]);
	/*if(threadIdx.x+blockIdx.x*blockDim.x<dwidth){
	int i,idx,idy;
	int num=0;
	for(i=0;i<dheight;i++)
	{
		idx=(threadIdx.x+i*dwidth)/blockDim.x;
		idy=(threadIdx.x+i*dwidth)%blockDim.x;
		num+=add[idy+idx*blockDim.x];
	}
	printf("%d  ",num);}*/
	int i,j,num;
	int idx=threadIdx.x+blockIdx.x*blockDim.x;
	int idy;
	printf("(%d,%d)\n",threadIdx.x,idx);
	int *add=(int *)((int *)b);//,pointarr[threadIdx.y][threadIdx.x]);
	for(i=0;i<dmul;i++)
	{
		idy=dmul*idx+i;
		num=0;
		if(idy<dheight){

			for(j=0;j<dwidth;j++)
			{
				num+=add[idy*dwidth+j];
			}
			printf("(%d,%d):%d\n",idx,idy,num);
		}
	}
}

int main()
{
	int a[height][width];
	int c[height][width];
	int **b;
	int thread_size=10;
	int block_size=1;
	int mul;
	mul=(height/(thread_size*block_size))+1;
	for(int i=0;i<height;i++)
	{
		for(int j=0;j<width;j++)
		{
			a[i][j]=j+i*width;
			c[i][j]=0;
			printf("%d  ",a[i][j]);
		}
		printf("\n");
	}
	cudaMalloc((void **)&b,size);
	cudaMemcpy(b,a,size,cudaMemcpyHostToDevice);
	dim3 threads(thread_size,1);
	dim3 blocks(block_size,1);
	testkernel<<<blocks,threads>>>(b,height,width,mul);
	cudaDeviceSynchronize();
	cudaMemcpy(c,b,size,cudaMemcpyDeviceToHost);
	for(int i=0;i<height;i++)
	{
		for(int j=0;j<width;j++)
		{
			printf("%d  ",c[i][j]);
		}
		printf("\n");
	}
	return 0;
}
