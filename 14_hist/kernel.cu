
#include "common.h"
#include "device_launch_parameters.h"

#define SIZE (100 * 1024 * 1024)

__global__ void histo_kernel(unsigned char *buffer, long size, unsigned int *histo) {
	__shared__ unsigned int temp[256];
	temp[threadIdx.x] = 0;
	__syncthreads();

	int i = threadIdx.x + blockIdx.x * blockDim.x;
	int stride = blockDim.x * gridDim.x;

	while (i < size) {
		atomicAdd(&temp[buffer[i]], 1);
		i += stride;
	}
	__syncthreads();

	atomicAdd(&histo[threadIdx.x], temp[threadIdx.x]);
}

int main(void) {
	unsigned char *buffer = (unsigned char*)big_random_block(SIZE);

	cudaEvent_t start, stop;
	HANDLE_ERROR(cudaEventCreate(&start));
	HANDLE_ERROR(cudaEventCreate(&stop));

	HANDLE_ERROR(cudaEventRecord(start, 0));

	unsigned char *dev_buffer;
	HANDLE_ERROR(cudaMalloc((void**)&dev_buffer, SIZE));
	HANDLE_ERROR(cudaMemcpy(dev_buffer, buffer, SIZE, cudaMemcpyHostToDevice));

	unsigned int *dev_histo;
	HANDLE_ERROR(cudaMalloc((void**)&dev_histo, sizeof(long) * 256));
	HANDLE_ERROR(cudaMemset(dev_histo, 0, sizeof(int) * 256));

	cudaDeviceProp prop;
	HANDLE_ERROR(cudaGetDeviceProperties(&prop, 0));
	int blocks = prop.multiProcessorCount * 2;

	histo_kernel << <blocks, 256 >> >(dev_buffer, SIZE, dev_histo);

	HANDLE_ERROR(cudaEventRecord(stop, 0));
	HANDLE_ERROR(cudaEventSynchronize(stop));

	float   elapsedTime;
	HANDLE_ERROR(cudaEventElapsedTime(&elapsedTime, start, stop));
	printf("Time to generate:  %3.3f ms\n", elapsedTime);

	unsigned int histo[256];
	HANDLE_ERROR(cudaMemcpy(histo, dev_histo, sizeof(int) * 256, cudaMemcpyDeviceToHost));

	long histoCount = 0;
	for (int i = 0; i < 256; i++)
		histoCount += histo[i];

	for (int i = 0; i < SIZE; i++)
		histo[buffer[i]]--;
	for (int i = 0; i < 256; i++)
		if (histo[i] != 0)
			printf("Failure at %d!\n", i);

	printf("Histogram Sum: %d\n", histoCount);

	HANDLE_ERROR(cudaEventDestroy(start));
	HANDLE_ERROR(cudaEventDestroy(stop));

	free(buffer);

	return 0;
}
