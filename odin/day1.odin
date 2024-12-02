package main

import "core:fmt"
import "core:math"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"

main :: proc() {
	data, ok := os.read_entire_file_from_filename("../data/day1")

	if !ok {
		fmt.println("failed to open file")
		return
	}

	stringData := string(data)

	left_list: [dynamic]int
	right_list: [dynamic]int
	score := make(map[int]int)

	lines := strings.split_lines(stringData)
	for line in lines {
		if len(line) == 0 {
			continue
		}

		elements := strings.split(line, "   ")

		left := strconv.atoi(elements[0])
		right := strconv.atoi(elements[1])

		append(&left_list, left)
		append(&right_list, right)

		num, ok := score[right]
		if ok {
			score[right] = num + 1
		} else {
			score[right] = 1
		}
	}

	slice.sort(left_list[:])
	slice.sort(right_list[:])

	sum: int
	similarity: int

	for i := 0; i < len(left_list); i += 1 {
		left := left_list[i]
		right := right_list[i]

		sum += math.abs(left - right)

		num, ok := score[left]
		if ok {
			similarity += left * num
		}
	}

	fmt.printfln("part1: %d", sum)
	fmt.printfln("part2: %d", similarity)
}
