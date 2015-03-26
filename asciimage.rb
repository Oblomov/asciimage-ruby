#!/usr/bin/ruby

# Ruby code to parse an ASCIImage

class ASCIImage

	MARKS = ['1'..'9', 'A'..'Z', 'a'..'n', 'p'..'z'].map { |r| r.to_a }.flatten

	OPTIONS = {
		# default fill color for (closed) paths:
		'fill' => 'black',
		# default stroke color for paths:
		'stroke' => 'black',
		# default stroke width for paths, in pixels:
		'stroke-width' => 1,
		# should paths be open? (default: no, paths are closed automatically)
		'open-path' => false,
		# should paths be aliased? (default: no, use anti-aliasing)
		'aliased' => false
	}

	# rows, columns, elements
	attr :rows, :cols, :els

	# metadata
	# metadata includes global and per-path options,
	# as well as things such as title, author or whatever
	attr :meta

	# convert the list of position into an element; multi is true
	# if the list is generated from a single mark with multiple
	# occurrences
	def add_element(list, multi)
		el_class = list.length == 1 ? :point :
			(!multi ? :path : (list.length == 2 ? :line : :ellipse))
		return [el_class, list.dup]
	end

	# create a rows by cols image with the given marks list;
	# marks is a map of marks to the pixel coordinates they appear in;
	# md is a set of options that may override the defaults
	# (either globally or per-path) and other metadata
	def initialize(rows, cols, marks, md)
		@rows = rows
		@cols = cols
		@els = [] # array of elements, to be created from the marks
		@meta = OPTIONS.merge md

		# list of consecutive marks
		current_list = []
		last_mark_idx = nil # index of last mark in the current list
		MARKS.each_with_index do |m, i|
			# we need to interrupt the previous list if the current mark has
			# more than one occurence (or none), or if the current mark is not
			# consecutive to the last one
			break_list = (marks[m].length != 1 or last_mark_idx != i - 1)

			# close element if necessary
			if break_list and not current_list.empty?
				@els << self.add_element(current_list, false)
				current_list.clear
				last_mark_idx = nil
			end

			# we're done if the current mark wasn't present
			next if marks[m].length == 0

			# otherwise (re)fill the list
			current_list += marks[m]
			last_mark_idx = i

			# and close the element if it was a repeated mark
			if marks[m].length != 1
				@els << self.add_element(current_list, true)
				current_list.clear
				last_mark_idx = nil
			end
		end

		# close the last element
		@els << self.add_element(current_list, false) unless current_list.empty?

	end

	# Parse an ASCIImage passed as an array of lines, with additional
	# optional metadata
	def self.parse(lines, metadata={})

		# some sanity checks
		raise "no Array given" unless Array === lines
		raise "empty Array given" unless lines.length > 0

		# discard ending newlines
		ll = lines.map { |l| l.chomp }
		raise "lines are not all equal length" unless ll.map { |l| l.length }.uniq.length == 1

		# strip all whitespace and transform the image into a 2D array of characters
		pixs = ll.map { |l| l.gsub(/\s+/,'').scan(/./) }

		# TODO FIXME we should actually check for misaligned pixels the way
		# the original ObjC code does
		raise "cleaned lines are not all equal length, are pixel equal-sized?" unless \
			pixs.map { |l| l.length }.uniq.length == 1

		rows = pixs.length
		cols = pixs.first.length

		# map marks to their coordinates, ignoring anything which isn't a mark
		marks = Hash.new { |h, k| h[k] = [] }

		pixs.each_with_index do |row, rn|
			row.each_with_index do |el, cn|
				marks[el] << [rn, cn] if MARKS.include? el
			end
		end

		return ASCIImage.new(rows, cols, marks, metadata)
	end
end

