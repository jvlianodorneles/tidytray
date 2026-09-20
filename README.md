# TidyTray

O organizador unificado definitivo para a barra de status do **[Omarchy](https://omarchy.org/)** (Quickshell / Wayland / Hyprland).

O **TidyTray** sintetiza e aprimora as melhores características, práticas e arquiteturas de 7 plugins de referência da comunidade:
- **`omarchy-tinytray`**: Hospedagem híbrida de widgets e ícones SNI com deduplicação inteligente (ex: suprime o ícone proprietário do Dropbox quando o widget oficial está ativo) e filtragem de itens fantasmas (LocalSend).
- **`omaice`**: Ocultação dinâmica e modo de faixa flutuante sem deslocar elementos vizinhos.
- **`nook`**: Modo gaveta suspensa abaixo da barra e arrasto interativo (drag-and-drop) fluido.
- **`omarchy-tray`**: Suporte total a submenus recursivos via DBus (`QsMenuOpener` stack) e captura transparente de qualquer plugin da barra em `shell.json`.
- **`omarchy-flat-tray` & `gamut`**: Filosofia "Flat" de visibilidade direta ("glanceability"), exibindo tudo na barra e ocultando o chevron quando nada estiver na gaveta.
- **`Omarchy-drawer`**: Painel estruturado com visualização em Grade (Grid) e Lista (List), busca instantânea e chaveamento rápido por toggles.

---

## Recursos Principais

### 1. 4 Modos de Apresentação (Configuráveis)
Você decide como o TidyTray deve se comportar:
- **`inline` (Slide-out)**: Expande suavemente na própria barra ao lado do indicador com animação cúbica. Perfeito quando alocado na extremidade da barra.
- **`dropdown` (Faixa Flutuante)**: Revela os itens em uma faixa compacta suspensa diretamente abaixo da barra. **Zero deslocamento** de relógio, workspaces ou botões vizinhos.
- **`drawer` (Card em Grade ou Lista)**: Abre um card popout com busca rápida, alternância entre Grade de ícones ou Lista detalhada.
- **`flat` (Visibilidade Total)**: Desdobra todos os ícones e widgets diretamente na barra. O botão chevron desaparece automaticamente se não houver itens recolhidos.

### 2. Cidadãos de Primeira Classe: SNI + Bar Widgets
- **Bandeja do Sistema (SNI / DBus)**: Suporte completo a ícones temáticos, pixmaps HiDPI, menus com submenus navegáveis, scroll (para volume, etc.) e botões esquerdo, direito e meio.
- **Widgets da Barra**: Arraste qualquer widget da barra (Bluetooth, Rede, Mídia, Monitor, etc.) para dentro do TidyTray; ele mantém suas funções, tooltips e painéis intactos.

### 3. Arrastar e Soltar (Drag & Drop) Interativo
- **Arrastar para o Tray**: Arraste qualquer widget da barra sobre o TidyTray para capturá-lo. O `DropCaret` mostra exatamente o ponto de inserção.
- **Reordenar no Tray**: Arraste itens entre si para mudar a ordem.
- **Arrastar de Volta**: Arraste um widget para fora para devolvê-lo à barra principal.

### 4. Hub de Gerenciamento & Flip 3D
- Clique com o botão direito no indicador ou pressione a tecla `s` para girar o painel em **perspectiva 3D**.
- No verso:
  - Busca instantânea por nome ou ID.
  - Toggles rápidos para Fixar (Pin), Ocultar (Hide) ou Ejetar widgets.
  - Alternância imediata entre os 4 modos de exibição.
  - Seletor de indicador (`chevron`, `dot`, `dots`, `plus`, `none`).
  - Timer de auto-recolhimento (`rehideSeconds`).

### 5. Wayland Keyboard-First
Totalmente operável sem encostar no mouse:
- **`Setas`**: Navegue pelos itens e menus.
- **`Tab` / `Shift+Tab`**: Ciclo de foco lógico.
- **`s`**: Abre as configurações / gerenciamento (Flip 3D).
- **`Esc`**: Fecha o painel ou volta um nível no submenu.

---

## Instalação

Como o plugin declara `"clonedFrom": "omarchy.tray"` no `manifest.json`, ativá-lo substitui a bandeja nativa sem gerar ícones duplicados:

```bash
omarchy plugin add https://github.com/jvlianodorneles/tidytray.git --enable
```

Para reiniciar a shell e aplicar as mudanças:
```bash
omarchy restart shell
```

---

## Configurações (`schema`)

As opções podem ser alteradas tanto pelo menu de gerenciamento quanto em `~/.config/omarchy/shell.json`:

| Chave | Tipo | Padrão | Descrição |
| :--- | :--- | :--- | :--- |
| `displayMode` | enum | `"inline"` | `"inline"`, `"dropdown"`, `"drawer"`, `"flat"` |
| `trigger` | enum | `"click"` | `"click"` ou `"hover"` |
| `indicatorIcon` | enum | `"chevron"` | `"chevron"`, `"dot"`, `"dots"`, `"plus"`, `"none"` |
| `rehideSeconds`| int | `0` | Segundos para fechar sozinho (0 = desativado) |
| `revealDuration`| int | `200` | Duração da animação de abertura (ms) |
| `deduplicateKnown`| bool | `true` | Suprime ícones redundantes de apps com widget nativo |

---

## Licença

MIT © Juliano Dorneles
