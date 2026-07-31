import os
import base64

def convert_dfpwm_to_base64():
    """
    Converts all .dfpwm files in the current directory to base64 encoded .txt files.
    """
    # Get the current working directory
    current_directory = os.getcwd()
    print(f"Searching for .dfpwm files in: {current_directory}")

    # Iterate over all files in the current directory
    for filename in os.listdir(current_directory):
        # Check if the file has a .dfpwm extension
        if filename.endswith(".dfpwm"):
            dfpwm_filepath = os.path.join(current_directory, filename)
            output_filename = os.path.splitext(filename)[0] + ".txt"
            output_filepath = os.path.join(current_directory, output_filename)

            try:
                # Read the binary content of the .dfpwm file
                with open(dfpwm_filepath, "rb") as dfpwm_file:
                    dfpwm_content = dfpwm_file.read()

                # Encode the content to base64
                base64_encoded_content = base64.b64encode(dfpwm_content)

                # Write the base64 encoded content to a new .txt file
                # We decode to 'utf-8' because b64encode returns bytes, and we want to write text
                with open(output_filepath, "w") as output_file:
                    output_file.write(base64_encoded_content.decode('utf-8'))

                print(f"Successfully converted '{filename}' to '{output_filename}'")

            except IOError as e:
                print(f"Error processing file '{filename}': {e}")
            except Exception as e:
                print(f"An unexpected error occurred with '{filename}': {e}")
    print("Conversion process completed.")

# Call the function to start the conversion
if __name__ == "__main__":
    convert_dfpwm_to_base64()
