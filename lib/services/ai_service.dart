import 'dart:convert';
import 'package:firebase_vertexai/firebase_vertexai.dart';

class AiService {
  Future<Map<String, String>> getFeedback({
    required int goal,
    required int spent,
    required Map<String, int> categories,
  }) async {
    final int saved = goal - spent;

    final model = FirebaseVertexAI.instance.generativeModel(
      model: 'gemini-2.5-flash-lite',
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.8,
        maxOutputTokens: 1000,
      ),
      systemInstruction: Content.system('너는 한국의 최신 물가와 트렌드를 잘 아는 유머러스한 재무 상담사야.'),
    );

    final prompt = '''
    이번 달 내 가계부 데이터는 아래와 같아.
    
    - 목표 예산: $goal원
    - 총 지출: $spent원
    - 차액(남은 돈): $saved원
    - 카테고리별 지출: $categories
    
    위 데이터를 바탕으로 아래 두 가지 값("comment", "keyword")을 가진 JSON 형식으로만 대답해. (설명, 마크다운 없이 오직 JSON만 출력)
    
    1. "comment": 
       - 상황별로 아주 구체적인 한국식 비유를 들어줘.
       - [절약 성공 시]: 남은 돈으로 할 수 있는 것을 '국밥', '스타벅스 아메리카노', '치킨', '편의점 맥주' 등으로 환산해서 칭찬해줘. (예: "와! 국밥이 무려 15그릇! 든든하다!")
       - [예산 초과 시]: 뼈 때리는 팩트 폭행과 함께 위로해줘. (예: "이 돈이면... 뜨끈한 국밥이 5그릇인데... 다음 달은 숨만 쉬고 살아야겠네요 ㅠㅠ")
       - [조언]: 지출이 가장 큰 카테고리를 언급하며 줄일 수 있는 현실적인 꿀팁을 한 문장으로 덧붙여줘.
       - 말투: ~해요 체로 친근하고 위트 있게, 이모지 많이 사용. 가독성을 위해 중간에 줄바꿈(\\n)을 꼭 넣어줘.

    2. "keyword":
       - 위 비유에 등장한 핵심 사물(음식, 물건 등)을 묘사하는 '영어 단어' (이미지 생성용).
       - 사진 퀄리티를 위해 구체적으로 적어줘. (예: delicious korean fried chicken, starbucks iced americano, luxury sports car)
       - 예산 초과로 슬픈 상황이면 'empty wallet crying face' 같은 거로.
    ''';

    try {
      // 3. AI에게 요청
      final response = await model.generateContent([Content.text(prompt)]);
      
      final rawText = response.text;
      
      if (rawText != null) {
        final cleanedJson = _cleanJson(rawText);
        final Map<String, dynamic> parsed = jsonDecode(cleanedJson);

        return {
          'comment': parsed['comment'] ?? '분석 결과를 불러오지 못했어요.',
          'keyword': parsed['keyword'] ?? 'money',
        };
      } else {
        return {
          'comment': 'AI가 아무 말도 하지 않았어요.',
          'keyword': 'error',
        };
      }
    } catch (e) {
      print('🚨 Firebase AI 에러: $e');
      return {
        'comment': 'AI 연결에 실패했습니다. (잠시 후 다시 시도해주세요)',
        'keyword': 'wifi',
      };
    }
  }

  String _cleanJson(String raw) {
    return raw.replaceAll('```json', '').replaceAll('```', '').trim();
  }
}