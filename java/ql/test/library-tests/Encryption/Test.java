package security.library.encryption;

import java.util.Arrays;
import java.util.List;

class Test {
	List<String> badStrings = Arrays.asList(
			"DES", 
			"des",
			"des_function",
			"function_using_des",
			"EncryptWithDES");
			
	List<String> goodStrings = Arrays.asList(
			"AES",
			"AES_function",
			// false negative - can't think of a good way to detect this without
			// catching things we shouldn't
			"AESEncryption");
			
	List<String> unknownStrings = Arrays.asList(
			// not a use of RC2 (camelCase is tricky)
			"GetPrc2",
			// not a use of DES
			"Description",
			// not a use of DES
			"DESTROY",
			// not a use of ECIES
			"species",
			// can't detect unknown algorithms
			"SOMENEWACRONYM");
}