# 🦖 DinoMath Run

> A corrida que também é um cálculo

Um *endless runner* 3D educacional em *low-poly* onde você controla um dinossauro que corre por um deserto infinito e precisa resolver operações matemáticas para superar os obstáculos no caminho.

Projeto acadêmico da disciplina de **Computação Gráfica** — [Unijorge](https://www.unijorge.edu.br).

## 🎮 Sobre o jogo

Enquanto o dinossauro corre automaticamente, obstáculos surgem à frente. Ao se aproximar de um obstáculo, o jogo entra em *slow motion* e exibe uma pergunta de matemática básica (adição, subtração, multiplicação e divisão, incluindo questões com incógnitas).

- **Acertou** → o dinossauro salta automaticamente e a corrida continua.
- **Errou ou o tempo esgotou** → você perde uma vida. Com três vidas zeradas, é Game Over.

O objetivo é sobreviver o máximo de tempo possível acumulando a maior pontuação.

## ✨ Funcionalidades

- Corrida infinita com cenário gerado proceduralmente
- Perguntas matemáticas das quatro operações básicas
- Questões com resultado, operando ou operador desconhecidos
- Sistema de dificuldade progressiva baseado no score
- Mecânica de *slow motion* ao se aproximar de obstáculos
- Sistema de 3 vidas, pontuação e combo
- Recorde local salvo entre sessões

## 🛠️ Tecnologias

| Camada | Tecnologia |
|---|---|
| Engine | [Godot 4.x](https://godotengine.org) |
| Linguagem | GDScript |
| Modelagem 3D | Blender |
| Formato de assets | GLB/GLTF |

## 📄 Documentação

O design completo do jogo está descrito no [Game Design Document](docs/DinoMath_GDD.md).

Os arquivos-fonte de modelagem 3D estão organizados em [blender/](blender/README.md).

## 🚀 Como rodar

1. Instale o [Godot 4.x](https://godotengine.org/download).
2. Clone o repositório (ou baixe o código-fonte).

3. Abra o projeto no Godot (Importar → selecione o arquivo `project.godot`).
4. Pressione `F5` para executar.

## 👥 Equipe

| Integrante | GitHub |
|---|---|
| Marcos Henrique | [@marcos-henri](https://github.com/marcos-henri) |
| William Araújo | [@WilliamOut](https://github.com/WilliamOut) |
| Kelvin Oliveira | [@kelvin-oliveira-dev](https://github.com/kelvin-oliveira-dev) |

## 📄 Licença

Este projeto é de uso educacional e acadêmico.
