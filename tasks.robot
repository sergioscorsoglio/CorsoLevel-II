*** Settings ***
Documentation     Orders robots from RobotSpareBin Industries Inc.
...               Saves the order HTML receipt as a PDF file.
...               Saves the screenshot of the ordered robot.
...               Embeds the screenshot of the robot to the PDF receipt.
...               Creates ZIP archive of the receipts and the images.

Library    RPA.Tables
Library    RPA.Excel.Files
Library    RPA.HTTP
Library    RPA.Browser.Selenium
Library    RPA.PDF
Library    RPA.Archive
Library    RPA.Robocorp.Vault
Library    RPA.Dialogs
Library    Screenshot
Library    RPA.Tasks
Library    OperatingSystem
Library    Process
Library    Collections
Library    RPA.Cloud.AWS
Library    RPA.JSON
Library    String


*** Variables ***
${DOWNLOAD_DIR}          ${CURDIR}${/}download
${TMP_DIR}               ${CURDIR}${/}temp-folder
${RECEIPT_DIR}           ${CURDIR}${/}output${/}receipt
${SCREENSHOT_DIR}        ${TMP_DIR}${/}screenshot  

${WEB_ORDER_URL}         https://--robotsparebinindustries.com/#robot-order
${ORDER_FILE_NAME}       orders.csv
${ORDER_FILE_FULL_PATH}  ${DOWNLOAD_DIR}${/}${ORDER_FILE_NAME}
${OUTPUT_ZIP_FILE_FULL_PATH}  ${OUTPUT_DIR}${/}receipt.zip

*** Keywords ***
Create directory if it is missing
    [Documentation]  Create the input directoey if it not exist and log the action.
    [Arguments]   ${Directory_path}
    ${rc}=  Run Keyword And Return Status    Directory Should Exist   ${Directory_path}
    IF    '${rc}' == 'False'
      Create Directory  ${Directory_path}
      Log  Created folder ${Directory_path}.
    ELSE
      Log  Folder ${Directory_path} already present.
    END

*** Keywords ***
Create project folders
    Create directory if it is missing  ${DOWNLOAD_DIR} 
    Create directory if it is missing  ${TMP_DIR}
    Create directory if it is missing  ${RECEIPT_DIR}
    Create directory if it is missing  ${SCREENSHOT_DIR}


*** Keywords ***
Ask for local repository path
    
    ${selectedFile}=  Set variable  ${Empty}
    ${dialog_result}=  Set variable  ${Empty}
    ${selected_file_count}=  Set variable  ${Empty}
    FOR    ${counter}    IN RANGE    1    4        
        Add heading    Select the order CSV file
        IF    ${counter} > 1
            Add icon    Warning
            Add text  WARNING: Order file not selected !
        END
        Add file input    name
        ${dialog_result}=    Run dialog  height=450      
        ${selected_file_count}=  Get length  ${dialog_result}[name]
        Log to console  ${selected_file_count}
        Exit For Loop If  ${selected_file_count} > 0
    END     
    IF  ${selected_file_count} > 0
      ${selectedFile}=  Set variable  ${dialog_result}[name][0]            
    ELSE
        Fail  No file selected from local repository
    END
    [Return]  ${selectedFile}

*** Keywords ***
Ask for CSV file location
    [Documentation]  Show modal dialog to ask to the user if download the order CSV file or get it from local computer
    
    ${secret}=  Get Secret  orders_urls
    ${dropdown_options}=    Convert To List  ${secret} 
    Add heading   Select the orders repository
    Add drop-down    name=download_url    options=@{dropdown_options}  default=official
    ${dialog_location}=    Run dialog  height=450 

    IF    "${dialog_location}[download_url]" == "local_repository"
        ${dialog_local_repository}=  Ask for local repository path
        ${result}=  Set variable  {"location":"${dialog_local_repository}", "local_repository":"TRUE"}
    ELSE 
        ${result}=  Set variable  { "location":"${secret}[${dialog_location}[download_url]]", "local_repository":"FALSE"}
    END   
    Log To Console    Selected CSV file location is: ${result}
    ${result}=  Replace String  ${result}  \\  \\\\
    Log To Console    Selected CSV file location is: ${result}
    &{result_json}=  Convert String to JSON  ${result}
    [Return]   &{result_json}

*** Keywords ***
Initialize
    [Documentation]  Initialize the process workflow
    Init Variables 
    Create project folders   
    Empty i/o folders and files
    Open the robot order website

*** Keywords ***
Init Variables
    [Documentation]  Initialize the process variables
    ${secret}  Get Secret  robotsparebinindustries_urls
    Set Global Variable  ${WEB_ORDER_URL}  ${secret}[home]/${secret}[order]
    Log  Web order url [${WEB_ORDER_URL}]

*** Keywords ***
Empty i/o folders and files
    [Documentation]  Empty the input and output folders
    Empty Directory    ${DOWNLOAD_DIR}
    Empty Directory    ${RECEIPT_DIR}
    Empty Directory    ${SCREENSHOT_DIR}

*** Keywords ***
Open the robot order website
    Open Available Browser  ${WEB_ORDER_URL}

*** Keywords ***
Close popup
    [Documentation]  Close the popup that appears when you open the order tab
    Click Button  OK

*** Keywords ***
Download orders file
    [Documentation]  Download the order file form the target URL and store it into the process download folder
    [Arguments]  ${order_file_url}
    Download  ${order_file_url}  ${ORDER_FILE_FULL_PATH}  overwrite=True
    [Return]  ${ORDER_FILE_FULL_PATH} 

*** Keywords ***
Get the orders from CSV file
    [Documentation]  Get the orders file and read the orders from CSV file
    [Arguments]  ${order_file_location_json}

    ${orders_file}=  Set Variable   ${Empty}
    IF    "${order_file_location_json.local_repository}" == "TRUE"
        ${orders_file}=  Set Variable  ${order_file_location_json}[location]
    ELSE
        ${orders_file}  Download orders file  ${order_file_location_json}[location]
    END
    ${orders_table}=  Read table from CSV  ${orders_file}
    [Return]  ${orders_table}

*** Keywords ***
Preview the robot and take robot screenshot
    [Documentation]  Display the image of the robot preview according to the features present in the purchase 
    ...  form and save the image for a later use
    Click Button  Preview    
    [Arguments]   ${order_number}
    ${screenshot_file}  Set Variable  ${SCREENSHOT_DIR}${/}${order_number}_robot_screenshot.png
    Screenshot  id:robot-preview-image  ${screenshot_file}
    [Return]  ${screenshot_file}

*** Keywords ***
Fill the order form
    [Documentation]  Fill the order form using order data from CSV file.
    ...  Warning: the Legs fiel id and name change each time!!
    [Arguments]  ${order}
    Select From List By Value    name:head   ${order}[Head]
    Select Radio Button    body  ${order}[Body]
    Input Text    xpath://input[@Placeholder='Enter the part number for the legs']  ${order}[Legs]
    Input Text  id:address  ${order}[Address]

*** Keywords ***
Store the receipt as a PDF file 
    [Documentation]   Store to a PDF file the HTML element containing the receipt summary.
    [Arguments]  ${order_number}
    Wait Until Element Is Visible    id:receipt
    ${receipt_html}  Get Element Attribute  id:receipt  outerHTML
    ${receipt_pdf_filename}  Set Variable  ${RECEIPT_DIR}${/}${order_number}_receipt.pdf
    Html To Pdf    ${receipt_html}    ${receipt_pdf_filename}
    [Return]  ${receipt_pdf_filename}

*** Keywords ***
Embed the robot screenshot to the receipt PDF file
    [Arguments]  ${screenshot}    ${receipt_pdf_filename}
    ${screenshot_as_list}=  Create List  ${screenshot}:align=center
    Add Files To Pdf  ${screenshot_as_list}  ${receipt_pdf_filename}  append=true
    
*** Keywords ***
Store receipt catch
    [Documentation]  Managing errors occurs while the process order. logs the error, the order number failed and go to next order starting point.
    [Arguments]  ${order}
    Log  ${KEYWORD STATUS} - Unrecoverable error while process the order n. ${order}[Order number]  level=ERROR
    # Here we can trace the order input information in a new excel file to recover the missing orders
    Go To  ${WEB_ORDER_URL} 

*** Keywords ***
Store receipt
    [Documentation]  Generate a PDF file containing the receipt and the image of the ordered robot.
    ...  The receipt is taken as the HTML containing the receipt summary. 
    ...  The robot image is taken as order preview image.
    [Arguments]  ${order}
    Close popup
    Fill the order form  ${order}
    ${screenshot}  Preview the robot and take robot screenshot  ${order}[Order number]
    Click Button    Order
    ${receipt_pdf_filename}  Store the receipt as a PDF file    ${order}[Order number]
    Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${receipt_pdf_filename}
    Click Button    id:order-another
    [Teardown]  Run Keyword If  "${KEYWORD STATUS}" == "FAIL"   Store receipt catch  ${order}

*** Keywords ***
Process
    [Documentation]  Loop over input orders to order the robots. If the order action fails, warns into the log and goes on
    ${order_file_location}  Ask for CSV file location
    ${orders_table}  Get the orders from CSV file  ${order_file_location}
    FOR    ${order}    IN    @{orders_table}
        # Run Keyword And Warn On Failure  Store receipt  ${order}
        Wait Until Keyword Succeeds  2 min  1 sec  Store receipt  ${order}
    END
    Archive Folder With ZIP   ${RECEIPT_DIR}   ${OUTPUT_ZIP_FILE_FULL_PATH}

*** Keywords ***
End message to the User
    [Documentation]  Tells the user the process is finished
    Add icon      Success
    Add heading   The purchase orders are finished. Good bye!
    Add submit buttons    buttons=Ok
    Add text  Output Zip file:
    ${files_trovati}  Add files  ${OUTPUT_ZIP_FILE_FULL_PATH}    
    Run dialog  height=450    

*** Keywords ***
End Process
    [Documentation]  Do the elaboration end process actions
     Close All Browsers
    End message to the User

*** Tasks ***
Main 
    [Documentation]  Order robots from RobotSpareBin Industries Inc. Orders list is  
    
    Initialize
    Process
    End Process
    Log  Done.
