extends GutTest
## Tests SVG label sanitising for generated node names.


func test_replaces_invalid_characters() -> void:
	assert_eq(InkscapeNodeNames.sanitize(" Body:1 ", "Fallback"), "Body_1")
	assert_eq(InkscapeNodeNames.sanitize("a/b\\c\"d@e", "Fallback"), "a_b_c_d_e")


func test_blank_label_uses_fallback() -> void:
	assert_eq(InkscapeNodeNames.sanitize("", "Head"), "Head")
	assert_eq(InkscapeNodeNames.sanitize("   ", "Head"), "Head")


func test_invalid_characters_in_fallback_are_replaced() -> void:
	assert_eq(InkscapeNodeNames.sanitize("", ".."), "__")
