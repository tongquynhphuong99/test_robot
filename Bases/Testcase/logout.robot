*** Settings ***
Library    SeleniumLibrary


*** Variables ***
${browser}    chrome
${url}    https://192.168.10.1/
${username}    admin
${password}    ttcn@99CN
${WIDTH}             1920
${HEIGHT}            1080

*** Test Cases ***

Login
    ${tmp_dir}=    Evaluate    __import__('tempfile').mkdtemp()
    ${options}=    Evaluate    sys.modules['selenium.webdriver'].ChromeOptions()    sys

    Call Method    ${options}    add_argument    --headless
    Call Method    ${options}    add_argument    --no-sandbox
    Call Method    ${options}    add_argument    --disable-dev-shm-usage
    Call Method    ${options}    add_argument    --disable-gpu
    

    Open Browser    ${URL}    Chrome    options=${options}
    Go To    ${URL}

    Set Window Size    ${WIDTH}    ${HEIGHT}
    Maximize Browser Window

    loginWebgui
    logoutwebgui

    Close Browser
    Log To Console    Chrome options: ${options.arguments}
*** Keywords ***
loginWebgui
    Click Button    id:details-button
    Click Link    id:proceed-link
    Input Text    id:username    ${username}
    Input Text    id:password    ${password}
    Click Button    id:loginbutton

logoutwebgui
    Sleep    3
    Select Frame    header
    Click Element    xpath://*[@id="log
    Unselect Frame    
