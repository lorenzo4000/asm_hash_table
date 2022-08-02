#include <unordered_map>
#include <assert.h>
#include <iostream>
#include <cstdlib>
#include <chrono>

#define N 0x100000

typedef std::chrono::high_resolution_clock Clock;
using std::chrono::duration_cast;
using std::chrono::duration;
using std::chrono::milliseconds;


struct asm_hash_table {
	unsigned long int n_entries;
	unsigned long int key_size;
	unsigned long int size;
	unsigned char* data;
};

struct asm_hash_map {
	asm_hash_table table;
	unsigned long int value_size;
	unsigned long int size;
	unsigned char* data;
};

extern "C" void new_hash_map(long int n_entries_hint, long int key_size, long int value_size, asm_hash_map* map);
extern "C" unsigned char* hash_map_insert(unsigned long int key_size, unsigned char* key, unsigned long int value_size, unsigned char* value, asm_hash_map* map);
extern "C" unsigned char* hash_map_find(unsigned long int key_size, unsigned char* key, asm_hash_map* map);

int main() {
	auto map = std::unordered_map<long int, long int>();

	asm_hash_map asm_map = {0};
	new_hash_map(0x20, 8, 8, &asm_map);
	printf("entries before inserting: 0x%x\n", asm_map.table.n_entries);

	auto t1 = Clock::now();			
	for(long int i = 0; i < N; i++) {
		map.insert({i, i});	
	}
	auto tot_insert_time_map = ((duration<double, std::milli>)(Clock::now() - t1)).count();
	std::cout << "unordered_map total insert() time for " << N << " elements: " << tot_insert_time_map << " ms  --  average time per insert(): " << tot_insert_time_map / N << " ms" << std::endl;

	t1 = Clock::now();			
	for(long int i = 0; i < N; i++) {
		assert(i == *(long int*)hash_map_insert(8, (unsigned char*)&i, 8, (unsigned char*)&i, &asm_map));
	}
	auto tot_insert_time_table = ((duration<double, std::milli>)(Clock::now() - t1)).count();
	std::cout << "asm_hash_map total insert() time for " << N << " elements: " << tot_insert_time_table << " ms  --  average time per insert(): " << tot_insert_time_table / N << " ms" << std::endl;

	printf("entries after inserting: 0x%x\n", asm_map.table.n_entries);

	srand(time(NULL));
	double tot_time_map = 0;
	for(int i = 0; i < N; i++) {
		long int n = rand() % N;
  
		auto t1 = Clock::now();			
		assert((long int)n == map.find(n)->second);
		tot_time_map += ((duration<double, std::milli>)(Clock::now() - t1)).count();			
	}
	std::cout << "unordered_map total find() time for " << N << " elements: " << tot_time_map  << " ms  --  average time per find(): " << tot_time_map / N << " ms" << std::endl;

	double tot_time_table = 0;
	for(int i = 0; i < N; i++) {
		long int n = rand() % N;

		auto t1 = Clock::now();			
		assert((long int)n == *(long int*)hash_map_find(8, (unsigned char*)&n, &asm_map));
		tot_time_table += ((duration<double, std::milli>)(Clock::now() - t1)).count();			
	}
	std::cout << "asm_hash_map total find() time for " << N << " elements: " << tot_time_table  << " ms  --  average time per find(): " << tot_time_table / N << " ms" << std::endl;
	return 0;
}
