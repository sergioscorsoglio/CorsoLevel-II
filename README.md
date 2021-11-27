# Orders robots from RobotSpareBin Industries Inc.

This is my implementation of Robocorp Course level II exercise using the Standard Robot Framework template.

The robot actions are: 
- Download the order file list
- Ask the user for deleting existing previous outputs (if exist)
- For each order in the input list:
  - Saves the order HTML receipt as a PDF file.
  - Saves the screenshot of the ordered robot.
  - Embeds the screenshot of the robot to the PDF receipt.
- Creates ZIP archive of the receipts and the images.
- Notify to the user the end of the process.

If somethig goes wrong while the robot process an order, the next one is processed.

You'll find more detail on project requirements at [Robocorp Course Level II](https://robocorp.com/docs/courses/build-a-robot)

## Project folders
In this implementation the robot will create the following folder structure:

```bash
- project root -
                 |-download
                 |-output-|
                 |        |- receipt
                 |-temp-folder-|
                 |             |- screenshot
```

Into that's folders youll'find:
- Project root: robocorp standard files
- Project root/download: the order CSV file
- Project root/output: the execution logs and the receipts zip file.
- Project root/output/receipt: the PDF documents containing the receipts
- Temp-folder/screenshot: the robot screenshot

## License
[Apache](https://choosealicense.com/licenses/apache/)