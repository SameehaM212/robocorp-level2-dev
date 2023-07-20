*** Settings ***
Documentation     Orders robots from RobotSpareBin Industries Inc.
...               Saves the order HTML receipt as a PDF file.
...               Saves the screenshot of the ordered robot.
...               Embeds the screenshot of the robot to the PDF receipt.
...               Creates ZIP archive of the receipts and the images.

Library      RPA.Browser.Selenium  auto_close=${FALSE}
Library      RPA.HTTP
Library      RPA.Tables
Library      RPA.PDF
Library      RPA.Archive
Library      Collections
Library      RPA.Robocloud.Secrets
Library      OperatingSystem
Library    RPA.RobotLogListener

*** Variables ***
${url}            https://robotsparebinindustries.com/#/robot-order

${img_folder}     ${CURDIR}${/}image_files
${pdf_folder}     ${CURDIR}${/}pdf_files
${output_folder}  ${CURDIR}${/}output

${orders_file}    ${CURDIR}${/}orders.csv
${zip_file}       ${output_folder}${/}pdf_archive.zip
${csv_url}        https://robotsparebinindustries.com/orders.csv



*** Tasks ***
Open the robot order website
    Open Available Browser  ${url}  maximized=True

Click OK
    Wait Until Page Contains Element    class:alert-buttons 
    #Sleep  5 seconds
    Click Button    OK

    Download    url=${csv_url}         target_file=${orders_file}    overwrite=True


Loop over a list of items and log each of them
    ${orders}=    Get orders
    FOR    ${row}    IN    @{orders}
        #Log    ${row} 
        Fill the form    ${row}
        #Click Button When Visible    //button[@class="btn btn-dark"]
        Preview the robot
        Wait Until Keyword Succeeds    2min    500ms  Submit The Order
        ${orderid}  ${img_filename}=    Take a screenshot of the robot
        ${pdf_filename}=                Store the receipt as a PDF file    ORDER_NUMBER=${order_id}
        Embed the robot screenshot to the receipt PDF file     IMG_FILE=${img_filename}    PDF_FILE=${pdf_filename}
        Set Local Variable              ${btn_anotherorder}        //*[@id="order-another"]
        Click button                    ${btn_anotherorder}
        Click Button    OK       
    END
    Create a ZIP file of the receipts
    Log Out And Close The Browser

# Close the annoying modal
#     # Define local variables for the UI elements
#     Set Local Variable              ${btn_yep}        //*[@id="root"]/div/div[2]/div/div/div/div/div/button[2]
#     Wait And Click Button           ${btn_yep}

*** Keywords ***
Get orders
    ${table}=   Read table from CSV    path=${orders_file}
    # Log     ${table}
    RETURN    ${table}

Fill the form
    [Arguments]    ${row}

    Set Local Variable    ${order_number}     ${row}[Order number]
    Set Local Variable    ${head}             ${row}[Head]
    Set Local Variable    ${body}             ${row}[Body]
    Set Local Variable    ${legs}             ${row}[Legs]
    Set Local Variable    ${address}          ${row}[Address]

    Set Local Variable      ${input_head}       //*[@id="head"]
    Set Local Variable      ${input_body}       body
    Set Local Variable      ${input_legs}       xpath:/html/body/div/div/div[1]/div/div[1]/form/div[3]/input
    Set Local Variable      ${input_address}    //*[@id="address"]
    Set Local Variable      ${btn_preview}      //*[@id="preview"]
    Set Local Variable      ${btn_order}        //*[@id="order"]
    Set Local Variable      ${img_preview}      //*[@id="robot-preview-image"]

    Wait Until Page Contains Element  ${input_head}
    Wait Until Element Is Enabled   ${input_head}
    Select From List By Value       ${input_head}           ${head}

    Wait Until Element Is Enabled   ${input_body}
    Select Radio Button             ${input_body}           ${body}

    Wait Until Element Is Enabled   ${input_legs}
    Input Text                      ${input_legs}           ${legs}
    Wait Until Element Is Enabled   ${input_address}
    Input Text                      ${input_address}        ${address}

Preview the robot
    # Define local variables for the UI elements
    Set Local Variable              ${btn_preview}      //*[@id="preview"]
    Set Local Variable              ${img_preview}      //*[@id="robot-preview-image"]
    Click Button                    ${btn_preview}
    Wait Until Page Contains Element   ${img_preview}

Submit the order
    # Define local variables for the UI elements
    Set Local Variable              ${btn_order}        //*[@id="order"]
    Set Local Variable              ${lbl_receipt}      //*[@id="receipt"]

    Click button                    ${btn_order}
    Page Should Contain Element     ${lbl_receipt}

Take a screenshot of the robot
    # Define local variables for the UI elements
    Set Local Variable      ${lbl_orderid}      xpath://html/body/div/div/div[1]/div/div[1]/div/div/p[1]
    Set Local Variable      ${img_robot}        //*[@id="robot-preview-image"]

    # This is supposed to help with network congestion (I hope)
    # when loading an image takes too long and we will only end up with a partial download.
    Wait Until Element Is Visible   ${img_robot}
    Wait Until Element Is Visible   ${lbl_orderid} 

    #get the order ID   
    ${orderid}=                     Get Text            //*[@id="receipt"]/p[1]

    # Create the File Name
    Set Local Variable              ${fully_qualified_img_filename}    ${img_folder}${/}${orderid}.png

    Sleep   1sec
    Log To Console                  Capturing Screenshot to ${fully_qualified_img_filename}
    Capture Element Screenshot      ${img_robot}    ${fully_qualified_img_filename}
    
    [Return]    ${orderid}  ${fully_qualified_img_filename}
Store the receipt as a PDF file
    [Arguments]        ${ORDER_NUMBER}
    Wait Until Element Is Visible   //*[@id="receipt"]
    Log To Console                  Printing ${ORDER_NUMBER}
    ${order_receipt_html}=          Get Element Attribute   //*[@id="receipt"]  outerHTML
    Set Local Variable              ${fully_qualified_pdf_filename}    ${pdf_folder}${/}${ORDER_NUMBER}.pdf
    Html To Pdf                     content=${order_receipt_html}   output_path=${fully_qualified_pdf_filename}
    [Return]    ${fully_qualified_pdf_filename}

Embed the robot screenshot to the receipt PDF file
    [Arguments]     ${IMG_FILE}     ${PDF_FILE}

    Log To Console                  Printing Embedding image ${IMG_FILE} in pdf file ${PDF_FILE}

    Open PDF        ${PDF_FILE}

    # Create the list of files that is to be added to the PDF (here, it is just one file)
    @{myfiles}=       Create List     ${IMG_FILE}:x=0,y=0

    # Add the files to the PDF
    #
    # Note:
    #
    # 'append' requires the latest RPAframework. Update the version in the conda.yaml file - otherwise,
    # this will not work. The VSCode auto-generated file contains a version number that is way too old.
    #
    # per https://github.com/robocorp/rpaframework/blob/master/packages/pdf/src/RPA/PDF/keywords/document.py,
    # an "append" always adds a NEW page to the file. I don't see a way to EMBED the image in the first page
    # which contains the order data
    Add Files To PDF    ${myfiles}    ${PDF_FILE}     ${True}

    Close PDF           ${PDF_FILE}


Create a Zip File of the Receipts
    Archive Folder With ZIP     ${pdf_folder}  ${zip_file}   recursive=True  include=*.pdf

Log Out And Close The Browser
    Close Browser

   



