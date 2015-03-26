#!/usr/bin/ruby

# Ruby code to parse an ASCIImage

require 'yaml'

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

	# parsed per-path overrides, for simplicity
	attr :overrides

	# convert the list of position into an element; multi is true
	# if the list is generated from a single mark with multiple
	# occurrences
	def add_element(list, multi)
		el_class = list.length == 1 ? :point :
			(!multi ? :path : (list.length == 2 ? :line : :ellipse))
		return [el_class, list.dup]
	end

	# provide all element properties (default and overrides
	def element_props(index)
		if @overrides.has_key? index
			return @meta.merge @overrides[index]
		else
			return @meta
		end
	end

	# is a path open?
	def path_open?(index)
		return element_props(index)['open-path']
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

		# TODO ranges
		@overrides = @meta.select { |k, v| Numeric === k }

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
	def self.parse_raw(lines, metadata={})

		# some sanity checks
		raise ArgumentError, "no Array given" unless Array === lines
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

	# Parse a YAML ASCIImage
	#
	# A YAML ASCIImage is a YAML document or sets of documents containing
	# both metadata and an image. The image data itself is stored as
	# the content of the 'image' key in the YAML document. If multiple
	# YAML documents are present, they are assumed to be layers of the
	# same image
	#
	# The method supports loading from either:
	# * an array of Hashes (assumed created by a YAML.load_documents
	#   or similar method);
	# * an array of Strings (joined into a single string before
	#   passing them to YAML.load_documents);
	# * a String (which will get passed to YAML.load_documents).
	#
	# The `metadata` argument allows overrides of the original
	# document metadata
	def self.parse_yaml(source, metadata={})
		case source
		when Array
			case source.first
			when Hash
				docs = source
			when String
				docs = YAML.load_documents(source.join)
			else
				raise ArgumentError, "can't handle #{source.first.class}"
			end
		when String
			docs = YAML.load_documents(source)
		when Hash
			docs = [source]
		else
			raise ArgumentError, "can't handle #{source.class}"
		end

		raise "no YAML documents found" if docs.length < 1

		# if there is a single document, then it's expected to have
		# an 'image' key
		if docs.length == 1
			raise "no ASCIImage found" unless docs.first.has_key?('image')
			# the key is there, return the parsed ASCIImage, passing the whole
			# YAML document as options —yes, this means that the image source
			# will be in the metadata, and that's intentional
			return self.parse_raw(docs.first['image'].lines,
					      docs.first.merge(metadata))
		end

		# multi-image is a TODO
		raise NotImplementedError, "multi-image not supported yet"
	end

	# Parse an ASCIImage, autodetecting if it's in raw format or a (set of)
	# YAML document(s)
	def self.parse(source, metadata={})
		# the source should be either an Array of Strings or Hashes, or a String,
		# or a Hash
		case source
		when String
			# try YAML first, raw second
			return self.parse_yaml(source, metadata) rescue self.parse_raw(source, metadata)
		when Hash
			# assume YAML
			return self.parse_yaml(source, metadata)
		when Array
			case source.first
			when Hash
				# Hashes? assume YAML
				return self.parse_yaml(source, metadata)
			when String
				# try raw first, YAML second
				return self.parse_raw(source, metadata) rescue self.parse_yaml(source, metadata)
			else
				raise ArgumentError, "can't handle #{source.first.class}"
			end
		else
			raise ArgumentError, "can't handle #{source.class}"
		end

	end

end

