#include <stdio.h>
#include <cuda.h>

__global__ void stress_test() {
    float idx = blockIdx.x * blockDim.x + threadIdx.x;
    float a = 0.0f;
    for (int i = 0; i < 1000000; i++) {
    	a += sin(idx) * tan(idx) / cos(idx);
    }
}

int main() {
    int num_blocks = 64;
    int threads_per_block = 256;

    printf("Running GPU stress test, selecting device 0 ...\n");

    if(cudaSetDevice(0) != cudaSuccess){
        printf("Failed to select device 0!\n");
        return 6; // ENXIO No such device of address
    }

    stress_test<<<num_blocks, threads_per_block>>>();

    cudaDeviceSynchronize();

    printf("GPU stress test completed.\n");

    return 0;
}

