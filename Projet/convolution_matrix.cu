﻿#if defined(WIN32) || defined(_WIN32) || defined(__WIN32) && !defined(__CYGWIN__)
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#endif

#include <opencv2/opencv.hpp>
#include <vector>
#include <chrono>
#include <string>

using namespace std;

__global__ void convolution_matrix(unsigned char const* in, unsigned char* const out, std::size_t w, std::size_t h)
{
	auto i = blockIdx.x * blockDim.x + threadIdx.x;
	auto j = blockIdx.y * blockDim.y + threadIdx.y;

	int const hor1 = -2; int const hor2 = -1; int const hor3 = 0;
	int const hor4 = -1; int const hor5 = 1; int const hor6 = 1;
	int const hor7 = 0; int const hor8 = 1; int const hor9 = 2;

	if (i > 1 && j > 1 && i < w - 1 && j < h - 1)
	{
		for (int c = 0; c < 3; c++) {

			auto hh = (hor1 * in[((j - 1) * w + i - 1) * 3 + c] + hor2 * in[((j - 1) * w + i) * 3 + c] + hor3 * in[((j - 1) * w + i + 1) * 3 + c]
				+ hor4 * in[(j * w + i - 1) * 3 + c] + hor5 * in[(j * w + i) * 3 + c] + hor6 * in[(j * w + i + 1) * 3 + c]
				+ hor7 * in[((j + 1) * w + i - 1) * 3 + c] + hor8 * in[((j + 1) * w + i) * 3 + c] + hor9 * in[((j + 1) * w + i + 1) * 3 + c]);

			auto vv = (hor1 * in[((j - 1) * w + i - 1) * 3 + c] + hor2 * in[(j * w + i - 1) * 3 + c] + hor3 * in[((j + 1) * w + i - 1) * 3 + c]
				+ hor4 * in[((j - 1) * w + i) * 3 + c] + hor5 * in[(j * w + i) * 3 + c] + hor6 * in[((j + 1) * w + i) * 3 + c]
				+ hor7 * in[((j - 1) * w + i + 1) * 3 + c] + hor8 * in[(j * w + i + 1) * 3 + c] + hor9 * in[((j + 1) * w + i + 1) * 3 + c]);
			

			auto res = hh * hh + vv * vv;
			res = res > 255 * 255 ? 255 * 255 : res;
			out[(j * w + i) * 3 + c] = sqrt((float)res);
		}		
	}
}

void convolution_matrix(std::string name)
{
	cv::Mat m_in = cv::imread(name, cv::IMREAD_UNCHANGED);
	auto rgb = m_in.data;
	auto rows = m_in.rows;
	auto cols = m_in.cols;

	std::vector< unsigned char > g(3 * rows * cols);
	cv::Mat m_out(rows, cols, CV_8UC3, g.data());

	unsigned char* rgb_d;
	unsigned char* out_d;

	auto start = std::chrono::system_clock::now();
	cudaEvent_t cudaStart, cudaStop;
	cudaEventCreate(&cudaStart);
	cudaEventCreate(&cudaStop);

	cudaEventRecord(cudaStart);

	cudaMalloc(&rgb_d, 3 * rows * cols);
	cudaMalloc(&out_d, 3 * rows * cols);

	cudaMemcpy(rgb_d, rgb, 3 * rows * cols, cudaMemcpyHostToDevice);

	dim3 block(32, 32);
	dim3 grid((cols - 1) / block.x + 1, (rows - 1) / block.y + 1); //(4,4)

	convolution_matrix << <grid, block >> > (rgb_d, out_d, cols, rows);

	cudaMemcpy(g.data(), out_d, 3 * rows * cols, cudaMemcpyDeviceToHost);

	cudaEventRecord(cudaStop);
	cudaEventSynchronize(cudaStop);
	auto stop = std::chrono::system_clock::now();


	auto duration = stop - start;
	auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(duration).count();

	float elapsedTime;
	cudaEventElapsedTime(&elapsedTime, cudaStart, cudaStop);
	std::cout << "Temps kernel: " << elapsedTime << std::endl;
	cudaEventDestroy(cudaStart);
	cudaEventDestroy(cudaStop);
	auto err = cudaGetLastError();

	std::cout << "Erreur: " << err << std::endl;

	std::cout << ms << " ms" << std::endl;

	cv::imwrite("filter.jpg", m_out);

	cudaFree(rgb_d);
	cudaFree(out_d);
}