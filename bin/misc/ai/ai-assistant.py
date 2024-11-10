#/usr/bin/env python

import argparse
import google.generativeai as genai
import os
import stat
import sys

GEMINI_MODEL = 'gemini-1.5-flash'

def isInPipe(file_descriptor_no):
    mode = os.fstat(file_descriptor_no).st_mode
    return stat.S_ISFIFO(mode) or stat.S_ISREG(mode)

def getModel():
    genai.configure(api_key=os.environ["GEMINI_API_KEY"])
    model = genai.GenerativeModel(GEMINI_MODEL)
    return model

def getFromStdin():
    return sys.stdin.read().strip()

def printSeparator():
    print(50*'-')

def getPrompt(args=None, inputTxt=None):
    prompt = ""

    if args:
        if args.improve:
            prompt = 'I am expecting a text that is both professional and casual, just sounds kind and yet isn\'t too formal. I\'d also like to correct any grammar or other errors. Is the text below correct or can it be improved to meet the criteria mentioned?\n'
        elif args.translate:
            prompt = 'Translate to english the following text. Use a combination of professional and casual styles and propose something what isn\'t too formal, just sounds kind.\n'
        elif args.prompt:
            with open(args.prompt[0], 'rt') as f:
                prompt = f.read().strip()

    if not prompt and ((args and args.vim) or (not inputTxt)):
        writeMsgFile(msgFile, [inputTxt])
        if launchVim(msgFile) != 0:
            return ''
        inputTxt = '\n'.join(getInput(msgFile, 0).splitlines())

    if inputTxt:
        if prompt:
            prompt += f'\n{inputTxt}'
        else:
            prompt = inputTxt

    return prompt

def writeMsgFile(msgFile, content):
    if not content:
        return
    with open(msgFile, 'wt') as f:
        for l in content:
            if not l:
                continue
            f.write(l)
            f.write('\n')
        f.write('\n')

def appendTo(msgFile, content, text):
    if not text:
        return content
    with open(msgFile, 'at') as f:
        # f.write(7*'-' + '# {{{\n')
        f.write(text)
        f.write('\n')
        # f.write(7*'-' + '# }}}\n')
    content.append(text)
    return content

def getInput(msgFile, toSkip=0):
    inputTxt = ""
    with open(msgFile, 'rt') as f:
        for i, l in enumerate(f):
            if i >= toSkip:
                if l.strip():
                    inputTxt += l
    return inputTxt

def launchVim(msgFile):
    return os.system(f'vim --Fast -c "normal G" {msgFile} </dev/tty >/dev/tty')

debug = False
isStdout = True
firstTime = True
inputTxt = ""
prompt = ""
model = getModel()

if isInPipe(1):
    isStdout = False

argsParser = argparse.ArgumentParser()
argsParser.add_argument('-i', '--improve', action='store_true', help='improve text from input')
argsParser.add_argument('-t', '--translate', action='store_true', help='translate')
argsParser.add_argument('--prompt', type=str, nargs=1, help='use prompt from a file')
argsParser.add_argument('--chat', action='store_true', help='chat')
argsParser.add_argument('--id', type=str, nargs=1, help='file id')
argsParser.add_argument('-f', '--file', type=str, nargs=1, help='file')
argsParser.add_argument('-n', '--new', action='store_true', help='start wth an empty file')
argsParser.add_argument('--usage', action='store_true', help='usage')
argsParser.add_argument('--vim', action='store_true', help='capture stdin and launch vim for promting')
args = argsParser.parse_args()

msgFile = None

if args.usage:
    print('[-i | --improve ]')
    print('[-t | --translate]')
    print('[--chat]')
    print('[--vim]')
    print('[--id ID] [-f | --file FILE] [-n | --new]')
    print('[--help]')
    print()
    exit(0)

if args.file:
    msgFile = args.file
else:
    fId = os.getppid()
    if args.id:
        fId = args.id[0]
    if fId == "-" or not fId:
        fId = ''
    else:
        fId = f'-{fId}'
    msgFile = f'{os.environ["TMP_MEM_PATH"]}/ai-assist{fId}.tmp'

content = []

if os.path.exists(msgFile):
    if not args.new:
        with open(msgFile, 'rt') as f:
            while l := f.readline():
                if l := l.strip():
                    content.append(l)
    else:
        os.remove(msgFile)

if args.chat:
    chat = model.start_chat()

    while True:
        if launchVim(msgFile) > 0:
            break

        prompt = '\n'.join(getInput(msgFile, len(content)).splitlines())

        if not prompt:
            raise Exception('no prompt')

        content.append(prompt)

        response = chat.send_message(prompt)
        response = '\n'.join(response.text.splitlines())

        content = appendTo(msgFile, content, response)

    # print(chat.history)

elif isInPipe(0):
    prompt = '\n'.join(getFromStdin().splitlines())
    if not prompt:
        raise Exception('no input')

    prompt = getPrompt(args, '\n'.join(prompt.splitlines()))
    if not prompt:
        raise Exception('no prompt')

    response = model.generate_content(prompt)
    response = '\n'.join(response.text.splitlines())

    content = [prompt, response]

else:
    while True:
        if firstTime:
            firstTime = False
            _ = appendTo(msgFile, content, getPrompt(args))

        if launchVim(msgFile) > 0:
            break

        prompt = '\n'.join(getInput(msgFile, len(content)).splitlines())
        if not prompt:
            raise Exception('no prompt')

        content.append(prompt)

        response = model.generate_content(prompt)
        response = '\n'.join(response.text.splitlines())

        content = appendTo(msgFile, content, response)

if not isStdout or isInPipe(0):
    for l in content:
        print(l)

