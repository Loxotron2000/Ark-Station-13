//Luma coefficients suggested for HDTVs. If you change these, make sure they add up to 1.
#define LUMA_R 0.213
#define LUMA_G 0.715
#define LUMA_B 0.072

/// Datum which stores information about a matrix decomposed with decompose().
/datum/decompose_matrix
	///?
	var/scale_x = 1
	///?
	var/scale_y = 1
	///?
	var/rotation = 0
	///?
	var/shift_x = 0
	///?
	var/shift_y = 0

/// Decomposes a matrix into scale, shift and rotation.
///
/// If other operations were applied on the matrix, such as shearing, the result
/// will not be precise.
///
/// Negative scales are now supported. =)
/matrix/proc/decompose()
	var/datum/decompose_matrix/decompose_matrix = new
	. = decompose_matrix
	var/flip_sign = (a*e - b*d < 0)? -1 : 1 // Det < 0 => only 1 axis is flipped - start doing some sign flipping
	// If both axis are flipped, nothing bad happens and Det >= 0, it just treats it like a 180° rotation
	// If only 1 axis is flipped, we need to flip one direction - in this case X, so we flip a, b and the x scaling
	decompose_matrix.scale_x = sqrt(a * a + d * d) * flip_sign
	decompose_matrix.scale_y = sqrt(b * b + e * e)
	decompose_matrix.shift_x = c
	decompose_matrix.shift_y = f
	if(!decompose_matrix.scale_x || !decompose_matrix.scale_y)
		return
	// If only translated, scaled and rotated, a/xs == e/ys and -d/xs == b/xy
	var/cossine = (a/decompose_matrix.scale_x + e/decompose_matrix.scale_y) / 2
	var/sine = (b/decompose_matrix.scale_y - d/decompose_matrix.scale_x) / 2 * flip_sign
	decompose_matrix.rotation = arctan(cossine, sine) * flip_sign

/matrix/proc/TurnTo(old_angle, new_angle)
	. = new_angle - old_angle
	Turn(.) //BYOND handles cases such as -270, 360, 540 etc. DOES NOT HANDLE 180 TURNS WELL, THEY TWEEN AND LOOK LIKE SHIT

/**
 * Shear the transform on either or both axes.
 * * x - X axis shearing
 * * y - Y axis shearing
 */
/matrix/proc/Shear(x, y)
	return Multiply(matrix(1, x, 0, y, 1, 0))

//Dumps the matrix data in format a-f
/matrix/proc/tolist()
	. = list()
	. += a
	. += b
	. += c
	. += d
	. += e
	. += f

//Dumps the matrix data in a matrix-grid format
/*
a d 0
b e 0
c f 1
*/
/matrix/proc/togrid()
	. = list()
	. += a
	. += d
	. += 0
	. += b
	. += e
	. += 0
	. += c
	. += f
	. += 1

///The X pixel offset of this matrix
/matrix/proc/get_x_shift()
	. = c

///The Y pixel offset of this matrix
/matrix/proc/get_y_shift()
	. = f

/////////////////////
// COLOUR MATRICES //
/////////////////////

/* Documenting a couple of potentially useful color matrices here to inspire ideas
// Greyscale - indentical to saturation @ 0
list(LUMA_R,LUMA_R,LUMA_R,0, LUMA_G,LUMA_G,LUMA_G,0, LUMA_B,LUMA_B,LUMA_B,0, 0,0,0,1, 0,0,0,0)

// Color inversion
list(-1,0,0,0, 0,-1,0,0, 0,0,-1,0, 0,0,0,1, 1,1,1,0)

// Sepiatone
list(0.393,0.349,0.272,0, 0.769,0.686,0.534,0, 0.189,0.168,0.131,0, 0,0,0,1, 0,0,0,0)
*/

//Does nothing
/proc/color_matrix_identity()
	return list(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1, 0,0,0,0)

//Adds/subtracts overall lightness
//0 is identity, 1 makes everything white, -1 makes everything black
/proc/color_matrix_lightness(power)
	return list(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1, power,power,power,0)

//Changes distance hues have from grey while maintaining the overall lightness. Greys are unaffected.
//1 is identity, 0 is greyscale, >1 oversaturates colors
/proc/color_matrix_saturation(value)
	var/inv = 1 - value
	var/R = round(LUMA_R * inv, 0.001)
	var/G = round(LUMA_G * inv, 0.001)
	var/B = round(LUMA_B * inv, 0.001)

	return list(R + value,R,R,0, G,G + value,G,0, B,B,B + value,0, 0,0,0,1, 0,0,0,0)

//Changes distance colors have from rgb(127,127,127) grey
//1 is identity. 0 makes everything grey >1 blows out colors and greys
/proc/color_matrix_contrast(value)
	var/add = (1 - value) / 2
	return list(value,0,0,0, 0,value,0,0, 0,0,value,0, 0,0,0,1, add,add,add,0)

//Moves all colors angle degrees around the color wheel while maintaining intensity of the color and not affecting greys
//0 is identity, 120 moves reds to greens, 240 moves reds to blues
/proc/color_matrix_rotate_hue(angle)
	var/sin = sin(angle)
	var/cos = cos(angle)
	var/cos_inv_third = 0.333*(1-cos)
	var/sqrt3_sin = sqrt(3)*sin
	return list(
round(cos+cos_inv_third, 0.001), round(cos_inv_third+sqrt3_sin, 0.001), round(cos_inv_third-sqrt3_sin, 0.001), 0,
round(cos_inv_third-sqrt3_sin, 0.001), round(cos+cos_inv_third, 0.001), round(cos_inv_third+sqrt3_sin, 0.001), 0,
round(cos_inv_third+sqrt3_sin, 0.001), round(cos_inv_third-sqrt3_sin, 0.001), round(cos+cos_inv_third, 0.001), 0,
0,0,0,1,
0,0,0,0)

//These next three rotate values about one axis only
//x is the red axis, y is the green axis, z is the blue axis.
/proc/color_matrix_rotate_x(angle)
	var/sinval = round(sin(angle), 0.001); var/cosval = round(cos(angle), 0.001)
	return list(1,0,0,0, 0,cosval,sinval,0, 0,-sinval,cosval,0, 0,0,0,1, 0,0,0,0)

/proc/color_matrix_rotate_y(angle)
	var/sinval = round(sin(angle), 0.001); var/cosval = round(cos(angle), 0.001)
	return list(cosval,0,-sinval,0, 0,1,0,0, sinval,0,cosval,0, 0,0,0,1, 0,0,0,0)

/proc/color_matrix_rotate_z(angle)
	var/sinval = round(sin(angle), 0.001); var/cosval = round(cos(angle), 0.001)
	return list(cosval,sinval,0,0, -sinval,cosval,0,0, 0,0,1,0, 0,0,0,1, 0,0,0,0)


//Returns a matrix addition of A with B
/proc/color_matrix_add(list/A, list/B)
	if(!istype(A) || !istype(B))
		return color_matrix_identity()
	if(A.len != 20 || B.len != 20)
		return color_matrix_identity()
	var/list/output = list()
	output.len = 20
	for(var/value in 1 to 20)
		output[value] = A[value] + B[value]
	return output

//Returns a matrix multiplication of A with B
/proc/color_matrix_multiply(list/A, list/B)
	if(!istype(A) || !istype(B))
		return color_matrix_identity()
	if(A.len != 20 || B.len != 20)
		return color_matrix_identity()
	var/list/output = list()
	output.len = 20
	var/x = 1
	var/y = 1
	var/offset = 0
	for(y in 1 to 5)
		offset = (y-1)*4
		for(x in 1 to 4)
			output[offset+x] = round(A[offset+1]*B[x] + A[offset+2]*B[x+4] + A[offset+3]*B[x+8] + A[offset+4]*B[x+12]+(y == 5?B[x+16]:0), 0.001)
	return output

/**
 * Converts RGB shorthands into RGBA matrices complete of constants rows (ergo a 20 keys list in byond).
 * if return_identity_on_fail is true, stack_trace is called instead of CRASH, and an identity is returned.
 */
/proc/color_to_full_rgba_matrix(color, return_identity_on_fail = TRUE)
	if(!color)
		return color_matrix_identity()
	if(istext(color))
		var/list/L = ReadRGB(color)
		if(!L)
			var/message = "Invalid/unsupported color ([color]) argument in color_to_full_rgba_matrix()"
			if(return_identity_on_fail)
				stack_trace(message)
				return color_matrix_identity()
			CRASH(message)
		return list(L[1]/255,0,0,0, 0,L[2]/255,0,0, 0,0,L[3]/255,0, 0,0,0,L.len>3?L[4]/255:1, 0,0,0,0)
	if(!islist(color)) //invalid format
		CRASH("Invalid/unsupported color ([color]) argument in color_to_full_rgba_matrix()")
	var/list/L = color
	switch(L.len)
		if(3 to 5) // row-by-row hexadecimals
			. = list()
			for(var/a in 1 to L.len)
				var/list/rgb = ReadRGB(L[a])
				for(var/b in rgb)
					. += b/255
				if(length(rgb) % 4) // RGB has no alpha instruction
					. += a != 4 ? 0 : 1
			if(L.len < 4) //missing both alphas and constants rows
				. += list(0,0,0,1, 0,0,0,0)
			else if(L.len < 5) //missing constants row
				. += list(0,0,0,0)
		if(9 to 12) //RGB
			. = list(L[1],L[2],L[3],0, L[4],L[5],L[6],0, L[7],L[8],L[9],0, 0,0,0,1)
			for(var/b in 1 to 3)  //missing constants row
				. += L.len < 9+b ? 0 : L[9+b]
			. += 0
		if(16 to 20) // RGBA
			. = L.Copy()
			if(L.len < 20) //missing constants row
				for(var/b in 1 to 20-L.len)
					. += 0
		else
			var/message = "Invalid/unsupported color (list of length [L.len]) argument in color_to_full_rgba_matrix()"
			if(return_identity_on_fail)
				stack_trace(message)
				return color_matrix_identity()
			CRASH(message)

/proc/color_matrix_hsv(hue, saturation, value)
	hue = clamp(360 - hue, 0, 360)

	// This is very much a rough approximation of hueshifting. This carries some artifacting, such as negative values that simply shouldn't exist, but it does get the job done, and that's what matters.
	var/cos_a = cos(hue) // These have to be inverted from 360, otherwise the hue's inverted
	var/sin_a = sin(hue)
	var/rot_x = cos_a + (1 - cos_a) / 3
	var/rot_y = (1 - cos_a) / 3 - 0.5774 * sin_a // 0.5774 is sqrt(1/3)
	var/rot_z = (1 - cos_a) / 3 + 0.5774 * sin_a

	return list(
		round((((1-saturation) * LUMA_R) + (rot_x * saturation)) * value, 0.01), round((((1-saturation) * LUMA_R) + (rot_y * saturation)) * value, 0.01), round((((1-saturation) * LUMA_R) + (rot_z * saturation)) * value, 0.01),
		round((((1-saturation) * LUMA_G) + (rot_z * saturation)) * value, 0.01), round((((1-saturation) * LUMA_G) + (rot_x * saturation)) * value, 0.01), round((((1-saturation) * LUMA_G) + (rot_y * saturation)) * value, 0.01),
		round((((1-saturation) * LUMA_B) + (rot_y * saturation)) * value, 0.01), round((((1-saturation) * LUMA_B) + (rot_z * saturation)) * value, 0.01), round((((1-saturation) * LUMA_B) + (rot_x * saturation)) * value, 0.01),
		0, 0, 0
	)

/proc/RGBMatrixTransform(list/color, list/cm)
	ASSERT(cm.len >= 9)
	if(cm.len < 12)		// fill in the rest
		for(var/i in 1 to (12 - cm.len))
			cm += 0
	if(!islist(color))
		color = ReadRGB(color)
	color[1] = color[1] * cm[1] + color[2] * cm[2] + color[3] * cm[3] + cm[10] * 255
	color[2] = color[1] * cm[4] + color[2] * cm[5] + color[3] * cm[6] + cm[11] * 255
	color[3] = color[1] * cm[7] + color[2] * cm[8] + color[3] * cm[9] + cm[12] * 255
	return rgb(color[1], color[2], color[3])

/**
 * Assembles a color matrix, defaulting to identity
 */
/proc/rgb_construct_color_matrix(rr = 1, rg, rb, gr, gg = 1, gb, br, bg, bb = 1, cr, cg, cb)
	return list(rr, rg, rb, gr, gg, gb, br, bg, bb, cr, cg, cb)

/**
 * Assembles a color matrix, defaulting to identity
 */
/proc/rgba_construct_color_matrix(rr = 1, rg, rb, ra, gr, gg = 1, gb, ga, br, bg, bb = 1, ba, ar, ag, ab, aa = 1, cr, cg, cb, ca)
	return list(rr, rg, rb, ra, gr, gg, gb, ga, br, bg, bb, ba, ar, ag, ab, aa, cr, cg, cb, ca)


#undef LUMA_R
#undef LUMA_G
#undef LUMA_B
