; /** defines bool y puntero **/
%define NULL 0
%define TRUE 1
%define FALSE 0

section .data
    error_list_create db "Error: No se pudo crear la lista", 0
    error_node_create db "Error: No se pudo crear el nodo", 0

section .text

global string_proc_list_create_asm
global string_proc_node_create_asm
global string_proc_list_add_node_asm
global string_proc_list_concat_asm

; FUNCIONES auxiliares que pueden llegar a necesitar:
extern malloc
extern free
extern str_concat
extern fprintf
extern stderr
extern strlen
extern strcpy

; string_proc_list* string_proc_list_create(void)
string_proc_list_create_asm:
    push rbp
    mov rbp, rsp
    
    ; Allocate memory for the list (size = 16 bytes for two pointers)
    mov rdi, 16
    call malloc
    
    ; Check if allocation failed
    test rax, rax
    jz .error
    
    ; Initialize first and last to NULL
    mov qword [rax], NULL    ; first
    mov qword [rax + 8], NULL ; last
    
    pop rbp
    ret
    
.error:
    ; Print error message
    mov rdi, [stderr]
    lea rsi, [error_list_create]
    xor eax, eax  ; Clear eax for varargs functions
    call fprintf
    
    xor rax, rax ; Return NULL
    pop rbp
    ret

; string_proc_node* string_proc_node_create(uint8_t type, char* hash)
string_proc_node_create_asm:
    push rbp
    mov rbp, rsp
    
    ; Save parameters - x86_64 calling convention
    ; rdi = type (uint8_t)
    ; rsi = hash (char*)
    
    ; Allocate memory for the node (size = 32 bytes: next(8) + previous(8) + type(1) + padding(7) + hash(8))
    push rdi        ; Save type
    push rsi        ; Save hash
    mov rdi, 32
    call malloc
    
    ; Restore parameters
    pop rsi         ; Restore hash
    pop rdi         ; Restore type
    
    ; Check if allocation failed
    test rax, rax
    jz .error
    
    ; Initialize node fields
    mov qword [rax], NULL       ; next
    mov qword [rax + 8], NULL   ; previous
    mov byte [rax + 16], dil    ; type (1 byte from rdi)
    mov qword [rax + 24], rsi   ; hash (passed in rsi)
    
    pop rbp
    ret
    
.error:
    ; Print error message
    mov rdi, [stderr]
    lea rsi, [error_node_create]
    xor eax, eax  ; Clear eax for varargs functions
    call fprintf
    
    xor rax, rax ; Return NULL
    pop rbp
    ret

; void string_proc_list_add_node(string_proc_list* list, uint8_t type, char* hash)
string_proc_list_add_node_asm:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    ; Save arguments
    mov rbx, rdi        ; list
    mov r12b, sil       ; type (just the byte)
    mov r13, rdx        ; hash
    
    ; Create the node
    movzx edi, r12b     ; type - zero extend to 32 bits
    mov rsi, r13        ; hash
    call string_proc_node_create_asm
    
    ; Check if node creation failed
    test rax, rax
    jz .end
    
    ; Check if list is empty
    cmp qword [rbx], NULL
    jne .not_empty
    
    ; List is empty - set first and last to new node
    mov [rbx], rax      ; first = node
    mov [rbx + 8], rax  ; last = node
    jmp .end
    
.not_empty:
    ; List not empty - append to end
    mov rcx, [rbx + 8]  ; last node
    mov [rax + 8], rcx  ; new node->previous = last
    mov [rcx], rax      ; last->next = new node
    mov [rbx + 8], rax  ; last = new node
    
.end:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; char* string_proc_list_concat(string_proc_list* list, uint8_t type, char* hash)
string_proc_list_concat_asm:
    push rbp
    mov rbp, rsp
    sub rsp, 16         ; Create some stack space
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Save arguments
    mov rbx, rdi        ; list
    mov r12b, sil       ; type (just the byte)
    mov r13, rdx        ; hash
    
    ; Allocate memory for result (strlen(hash) + 1)
    mov rdi, r13
    call strlen         ; rax = strlen(hash)
    add rax, 1          ; +1 for null terminator
    mov rdi, rax
    call malloc
    
    ; Check if allocation failed
    test rax, rax
    jz .end
    
    ; Copy hash to result
    mov r14, rax        ; r14 = result
    mov rdi, r14
    mov rsi, r13
    call strcpy
    
    ; Iterate through the list
    mov r15, [rbx]      ; current_node = list->first
    
.loop:
    test r15, r15
    jz .end             ; if current_node == NULL, done
    
    ; Check if node type matches
    movzx eax, byte [r15 + 16]  ; current_node->type
    cmp al, r12b
    jne .next
    
    ; Types match - concatenate
    mov rdi, r14
    mov rsi, [r15 + 24] ; current_node->hash
    call str_concat
    
    ; Free old result
    mov rdi, r14
    mov r14, rax        ; new result
    call free
    
.next:
    mov r15, [r15]      ; current_node = current_node->next
    jmp .loop
    
.end:
    mov rax, r14        ; return result
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    add rsp, 16
    pop rbp
    ret