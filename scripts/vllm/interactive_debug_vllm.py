"""
This file contains a stand alone set of useful things to debug VLLM interactively.

- VLLMServer to easily start and stop a server
- Standalone LLMClient to interact with it
- 
"""

from typing import List, Dict

import openai
import asyncio
import time
import traceback


class MinimalLLMClient:
    def __init__(self, api_url: str, api_key: str = None, **default_kwargs):
        """
        hostname = "http://localhost:8000"

        If default_kwargs are provided then they will be used for all requests,
        and can be optionally overwritten by the kwargs in the individual requests.
        """
        self._api_key = api_key
        self._api_url = api_url
        self._default_kwargs = default_kwargs

    def get_chat_response(self, messages: List[Dict], **kwargs):
        try:
            all_kwargs = dict(self._default_kwargs)
            all_kwargs.update(kwargs)

            # Default generation params is "almost greedy decoding"
            if "temperature" not in all_kwargs and "top_p" not in all_kwargs:
                all_kwargs['temperature'] = 0.2
                all_kwargs['top_p'] = 0.9

            # have to set them before every call in case the user is using more than one LLMClient instance
            if openai.__version__ < "1.0.0":
                openai.api_key = self._api_key
                openai.api_base = self._api_url
                chat_completion = openai.ChatCompletion.create(
                    messages=messages,
                    **all_kwargs
                )
                return chat_completion["choices"][0]["message"]["content"]
            else:
                from openai import OpenAI
                client = OpenAI(base_url=self._api_url, api_key=self._api_key)

                def _is_not_openai_kwarg(_s):
                    return _s.startswith("guided_") or _s in ["top_k"]

                kwargs_without_guided = {k: v for k, v in all_kwargs.items() if not _is_not_openai_kwarg(k)}
                kwargs_with_guided = {k: v for k, v in all_kwargs.items() if _is_not_openai_kwarg(k)}

                completion = client.chat.completions.create(
                    messages=messages,
                    extra_body=kwargs_with_guided,
                    **kwargs_without_guided,
                )
                return completion.choices[0].message.content
        except Exception as ex:
            raise

    async def aget_chat_response(self, messages: List[Dict], **kwargs):
        """
        Get a single chat response, asynchronous call.
        """
        all_kwargs = dict(self._default_kwargs)
        all_kwargs.update(kwargs)

        # have to set them before every call in case the user is using more than one LLMClient instance
        valid_completion = False
        for k in range(5):
            try:
                # have to set them before every call in case the user is using more than one LLMClient instance
                if openai.__version__ < "1.0.0":
                    openai.api_key = self._api_key
                    openai.api_base = self._api_url
                    chat_completion = await openai.ChatCompletion.acreate(
                        messages=messages,
                        **all_kwargs
                    )
                    valid_completion = True
                    content = chat_completion["choices"][0]["message"]["content"]
                else:
                    from openai import AsyncOpenAI
                    client = AsyncOpenAI(base_url=self._api_url, api_key=self._api_key)
                    kwargs_without_guided = {k: v for k, v in all_kwargs.items() if not k.startswith("guided_")}
                    kwargs_with_guided = {k: v for k, v in all_kwargs.items() if k.startswith("guided_")}
                    completion = await client.chat.completions.create(
                        messages=messages,
                        extra_body=kwargs_with_guided,
                        **kwargs_without_guided,
                    )
                    valid_completion = True
                    content = completion.choices[0].message.content
            except Exception as exc:
                traceback.print_exc()
                time.sleep(1)
            if valid_completion:
                break
        if not valid_completion:
            raise Exception("Failed to get a valid completion")
        return content

    async def aget_batch_chat_responses(self, batch_messages: List[List[Dict]], num_workers=10, **kwargs):
        """
        Get a batch of chat messages.
        Each element of the batch must be a dict with keys:
            id: str
            messages: List[Dict]    # same as messages in get_chat_response
            kwargs: Dict            # optional kwargs for this request. If present, overwrites the global kwargs.

        Yields responses:
            {"id": str, "response": Dict}

        Note: the order of responses is not guaranteed to be the same as the order of the input batch.
        """
        work_queue = asyncio.Queue()
        output_queue = asyncio.Queue()

        async def worker():
            while True:
                id_and_messages = await work_queue.get()
                if id_and_messages is None:
                    await output_queue.put(None)
                    break
                if "kwargs" in id_and_messages:
                    msg_kwargs = dict(kwargs)
                    msg_kwargs.update(id_and_messages["kwargs"])
                else:
                    msg_kwargs = kwargs
                _start_time = time.time()
                chat_completion = await self.aget_chat_response(id_and_messages["messages"], **msg_kwargs)
                _end_time = time.time()
                await output_queue.put({"id": id_and_messages["id"], "response": chat_completion, "took": _end_time - _start_time})

        tasks = []
        for _ in range(num_workers):
            tasks.append(asyncio.create_task(worker()))

        for id_and_messages in batch_messages:
            await work_queue.put(id_and_messages)
        for _ in range(num_workers):
            await work_queue.put(None)

        num_workers_finished = 0
        while True:
            response = await output_queue.get()
            if response is None:
                num_workers_finished += 1
                if num_workers_finished == num_workers:
                    break
            else:
                yield response

        for task in tasks:
            task.cancel()
        # wait until all tasks are cancelled
        await asyncio.gather(*tasks, return_exceptions=True)

    def get_batch_chat_responses(self, batch_messages: List[List[Dict]], num_workers=10, **kwargs):
        """
        Get a batch of chat messages.
        Each element of the batch must be a dict with keys:
            id: str
            messages: List[Dict]    # same as messages in get_chat_response

        Yields responses:
            {"id": str, "response": Dict}

        Note: the order of responses is not guaranteed to be the same as the order of the input batch.
        """

        async def _go():
            responses = []
            k = 0
            start_time = time.time()
            total_took = 0
            async for response in self.aget_batch_chat_responses(batch_messages, num_workers, **kwargs):
                responses.append(response)
                total_took += response["took"]
                k += 1
                if k % 10 == 0:
                    _current_time = time.time()
                    _total_time = _current_time - start_time
                    _average_took = total_took / 10
                    total_took = 0
                    print(f"Response {k}, total time = {_total_time}, avg per response = {_total_time/k}")
                    print(f"Average end-to-end time for last 10 responses: {_average_took}")
            id_to_index = {response["id"]: k for k, response in enumerate(batch_messages)}
            sorted_responses = [None] * len(responses)
            for response in responses:
                sorted_responses[id_to_index[response["id"]]] = response
            return sorted_responses

        return asyncio.run(_go())




def get_vllm_client(url: str, api_key: str = None, **kwargs) -> MinimalLLMClient:
    return MinimalLLMClient(url, api_key, **kwargs)



prompt = [{'role': 'system', 'content': 'You are a shopping assistant on an e-commerce website helping a user make a purchase.\n- Keep the messages very short, to the point, and not repetitive.\n- Answer user queries using all of the context in the chat history.\n- After user messages that include UTTERANCE answer the question using all of the context in the chat history.\n- For user requests for suggested questions, respond with a list of 3 suggested questions.  Diversify the questions. Suggested questions should be answerable from the provided information. Don\'t suggest questions that you can\'t answer.\n- For user requests for suggested answers, respond with a list of 3 suggested answers followed by 1 or 2 questions.\n- Include GOAL, PRODUCT_ID, REVIEW_ID, and DOCUMENT_ID as needed.\n- The "GOAL: retrieval" produces a search query to retrieve information.\n- Do not bias any particular product and instead highlight the benefits of each product.\n- Try to sound like a trusted friend who is warm, unbiased, and conversational.\n- Use bold text and bullet points when appropriate. Include markdown links for product mentions.\n- Be careful with language to avoid making promises or guarantees.\n- Avoid “will,” “never,” “always,” “guaranteed.”\n- Use “up to,” “may,” “could,” “reduce,” “help,” etc.\n- Avoid superlatives like “best,” “most,” “cleanest,” “safest,” “softest,” “greenest.”\n- Use “better,” “cleaner,” “safer,” “softer,” etc.\n- Do not mention other brand names; just say “other brands.”\n- If asked about a competitor brand (e.g., “Should I switch from X brand?”), focus on Coterie’s positive features and reviews, without naming the other brand.\n- If asked about “Rolls-Royce/Tesla/Apple of diapers,” say “Coterie is a premium diaper brand…”\n- If asked for customer support issues (returns, shipping, order status, etc.), respond with “I’m here to help you find the right item and answer questions about our products. It sounds like your request may be related to Customer Support. For further assistance, you can reach out to our support team via email at hello@coterie.com.”\n\n## Facts about Coterie:\n- 12-hr leak protection to help prevent nighttime wakeups\n- Liquid capacity of over 16oz (as tested on size 4 diapers) + 4x faster absorbency for fewer leaks\n- 3x drier skin to minimize likelihood of diaper rash\n- The 4x faster absorbency and 3x drier skin are "in lab testing compared to leading brands"\n- Soft-as-cashmere, apparel-grade materials\n- Hypoallergenic, dermatologist tested, cruelty-free, 25% plant-based materials\n- No fragrance, lotion, latex, rubber, dyes, alcohol, parabens, phthalates, pesticides, chlorine bleaching, VOCs, or optical brighteners\n- The only diaper brand to publish our Safety Report\n- Designed for sleep\n- Faster wicking, more absorbent, made with cleaner, more sustainable ingredients\n- 9 out of 10 people who tried Coterie praise its absorbency / give it high marks for absorbency based on a consumer test conducted in 2023 by an independent research agency\n- 95% of people that use Coterie did not experience any skin irritation, including diaper rash\n- Free of 27 most common PFAS, including PFOA and PFOS. Can\'t claim to be 100% free of all PFAS. Performed well on independent testing like Mamavation.\n- 2024 awards:\n   - Parents\' Picks Awards: "Best Baby Products & Toddler Products"\n   - Babylist: "Best Disposable Diapers of 2024"\n   - NAPPA: "Best Diaper"\n   - NAPPA: "Best Wipe"\n   - The EveryMom: "Best Diaper Subscription"\n   - Forbes Vetted: "Best Diaper for Sensitive Skin"\n   - 2024 Baby Innovation Award: "Overnight Diaper Product of the Year"\n   - The Bump: "Best Overall Diaper"\n   - Parents.com Kid\'s Sleep Awards: "Best Products for Sleep: The Diaper"\n   - Good Housekeeping: "GH 2024 Parenting Awards: Best Wipe"\n- You do not know any other awards. If asked, say you don\'t know.\n- You do not know number of chemicals that are not in Coterie. If asked, list the chemicals without a number.\n- You may answer questions that are supported by faq or product details (e.g., a veteran discount) but NEVER provide instructions/support for processes outside of coterie (e.g., don\'t answer how to verify on GovX)\n- For customer support queries about orders, shipping, returns, etc, ask the user to email customer support at hello@coterie.com.\n- When asked about Rihanna or any other celebrity, say "Out of respect to our celebrity clients, we cannot share details about celebrities that use Coterie. However, Ashley Graham and Karlie Kloss have been official Coterie partners."\n- The 4x faster absorbency and 3x drier skin claims should always be followed by "in lab testing compared to leading brands".\n- Never use phrases like "Rolls-Royce/Tesla/Apple of diapers". This causes serious legal issues. When asked, dodge the question and say "Coterie is a premium diaper brand ... " without mentioning any other brands.\n- How does it compare with other brands? 4x faster absorbency, 3x drier skin (in lab testing compared to leading brands), clean ingredients, softness, positive reviews. Do not repeat the name of other brands.\n- Completely avoid phrases like "Superior Absorbency"\n- How is it better than Pampers? "Our [Diaper](the-diaper) offers up to 4x faster absorbency and up to 3x drier skin (in lab testing compared to leading brands), which helps reduce leaks and diaper rash." then talk about reviews.\n# Facts about [The Pant](the-pant):\nClean ingredients:\n- Hypoallergenic, dermatologist-tested, cruelty-free\n- No added fragrance, lotion, latex, rubber, dyes, alcohol, parabens, phthalates, pesticides, chlorine bleaching, VOCs, or optical brighteners\n- Ingredient List: Absorbent core made of sodium polyacrylate (SAP). Nonwoven topsheet, backsheet, and leg cuffs made from polypropylene/polyethylene and polyester. Elastic waistband made of polyurethane, polypropylene/polyethylene, and an elastomer. Fastening system made of polypropylene/polyethylene. Film, adhesives, wetness indicator.\n- Absorbent core made of sodium polyacrylate (SAP) (no wood pulp and no chlorine bleaching)\nCompared to traditional training pants, The Pant offers:\n- 2 ways to change: pull up and down like underwear (vertical changes), or change like a diaper (horizontal changes)\n- Resealable waistband: soft, stretchy, personalized fit designed for enhanced comfort around the hips and thighs + easy disposal (roll up like a burrito and seal)\n- Up to 2.5x more stretch than other training pants for free and comfortable movement\n- Up to 80% more liquid capacity to minimize leaks and blowouts (based on lab testing against other commercially available training pants)\n\n## Comparing to other brands  \n### When responding to questions asking to compare to other brands, we summarize reviews and talk about benefits but don\'t discuss other brands directly:\n#### Examples:\n- How is this better than Pampers?\n[discuss reviews highlight that our [Diaper](the-diaper) delivers superior absorbency and skin care benefits.]\n\n- How does it compare with Huggies?\n[Our [Diaper](the-diaper) has received positive reviews noting better absorbency, softness, and overall performance—always.]\n\n- Why is it better than Luvs?\n[discuss reviews that have found that our [Diaper](the-diaper) delivers on absorbency, leak protection, and skin safety, offering a compelling alternative without direct brand comparisons.]\n\n\n# Factuality\n- Your response should be supported by the inputs provided to you (product information, review information, document information)\n- Do not make up information that\'s not supported by the inputs. If the answer is not in the input data, say I don\'t know\n- For example, let\'s say all the input data doesn\'t have information about restocking fee. When the user ask about it, you can say something like "I don\'t have access to specific details about the restocking fee. Is there anything else I can help you with?\n\n# Taking actions\n- You can\'t take actions on behalf of the user or on behalf of the merchant including adding to cart, starting a return, sending email ... etc.\n- If the user\'s request require taking such action, say you are unable to, then direct the user to how to do it themselves or how to contact customer service.\n- For example, the user wants you to send them a refund. Your response can be something like "I\'m unable to process refunds. Please contact our customer service team for assistance."\n\n# Webpage navigation\n- Urls in chat history from faqs or product details can be repeated when helpful, however you don\'t know the location of menus, which pages exist, and can\'t generate urls unless they are in the chat history\n- If the user\'s request requires page navigation or links not in your chat history, say you are unable to help, then direct the user to contact customer service.\n- For example, the user wants to know where to find the Terms and Conditions page and you don\'t have a url for Terms and Conditions in your history. Your response can be something like "I don\'t have access to specific details about navigating to this page. Is there anything else I can help you with?"'}, {'role': 'user', 'content': 'Visiting the following product. This is the first product visit; just summarize.\nProduct Details Page View: the-diaper\n####\nPRODUCT_ID: the-diaper\nProduct Title: The Diaper\nWe optimize our boxes according to the average number of changes babies need as they grow. Each box contains 6 packs of diapers, approximately a one-month supply:\nNumber of Reviews: 7512. Average Rating: 4.8 / 5\n\nDetails Of The Current Displayed Variant of Product the-diaper\nTitle: None\nSize: 8-12 lbs\nQuantity: 198 Diapers is ~7 changes a day.\nOriginal Price: 100.0\nSale Price: 90.0\nDiscount: 10.0\nCurrency: USD\nAvailable: True\n\n\nProduct Variants:\nsize: 10-16 lbs, 14-24 lbs, 20-32 lbs, 27+ lbs, 35+ lbs, 41+ lbs, 8-12 lbs\nquantity: 108 Diapers is ~4 changes a day., 132 Diapers is ~5 changes a day., 150 Diapers is ~5 changes a day., 168 Diapers is ~6 changes a day., 186 Diapers is ~6 changes a day., 198 Diapers is ~7 changes a day., 96 Diapers is ~4 changes a day.\n\n\nsize + pack details: We optimize our boxes according to the average number of changes babies need as they grow. Each box contains 6 packs of diapers, approximately a one-month supply:\n- N (<10 lbs): 186 total count/box (~6 changes/ day)\n- N/1 (<10-12 lbs): 192 total count/box (~7 changes/ day); this box includes 3 packs of Size Newborn (93 count) + 3 packs of Size 1 (99 count)\n- 1 (8-12 lbs): 198 total count/box (~7 changes/ day)\n- 2 (10-16 lbs): 186 total count/box (~6 changes/ day)\n- 3 (14-24 lbs): 168 total count/box (~6 changes/ day)\n- 4 (20-32 lbs): 150 total count/box (~5 changes/ day)\n- 5 (27+ lbs): 132 total count/box (~5 changes/ day)\n- 6 (35+ lbs): 108 total count/box (~4 changes/ day)\n- 7 (41+ lbs): 96 total count/box (~4 changes/ day)\nEvery baby is different! You can modify Auto-Renew delivery frequency on your Account Page.\nclean ingredients: - Hypoallergenic, dermatologist tested, cruelty free, 25% plant-based materials\n- No added fragrance, lotion, latex, rubber, dyes, alcohol, parabens, phthalates, pesticides, chlorine bleaching, VOCs, or optical brighteners\n- Certified safe from 1,000+ potentially harmful chemicals* \n- Ingredient list: Absorbent core made of sodium polyacrylate (SAP) and Totally Chlorine Free (TCF) wood pulp from sustainably managed forests. Backsheet made from polypropylene, polyester and polyethylene. Topsheet made of polypropylene. High loft nonwoven acquisition layer made of polyester. Fastening system made of polypropylene/polyethylene. Adhesives, elastics, wetness indicator.\n*Certified to OEKO-TEX® STANDARD 100, #25.HUS.21538 Hohenstein\nbenefits of auto-renew: - Save 10% on every order\n- Delivered to your door on your schedule (every 3, 4, or 5 weeks)\n- Manage everything—from product size to delivery date—via text\n- Happiness guarantee: we’re standing by to help with any questions or issues\nwhy we love it: The Diaper offers:\n- Holds over 16 oz liquid (based on lab testing of size 4 diapers)\n- Up to 12-hr leak protection (we especially love this for overnights)\n- Up to 4x faster absorbency compared to leading brands to minimize leaks\n- Up to 3x drier skin compared to leading brands to minimize likelihood of diaper rash\n- Ultra-soft, apparel-grade materials for comfort\n- Wetness indicator alerts when a change is needed\n- Newborn size includes an umbilical cord notch + Newborn size and Size 1 include overlapping tabs for a snug, customizable fit\nsize chart: Size\tWeight ranges (lbs)\tDiapers per delivery\tChanges per day\nN\t< 10\t186\t~7\nN/1\t< 10\t192\t~7\n1\t8 - 12\t198\t~7\n2\t10 - 16\t186\t~6\n3\t14 - 24\t168\t~6\n4\t20 - 32\t150\t~5\n5\t27+\t132\t~5\n6\t35+\t108\t~4\n7\t41+\t96\t~4\nFAQs: Q1: Can a really great diaper really make a difference? \nA1: Will our diapers do your dishes and taxes? Probably not. However, a really great baby diaper experience can help soften the landing into new parenthood in a few key ways. \nMinimized leaks and blowouts can mean you’re not waking up 3 times in the middle of the night to change diapers, clothes, and crib sheets. \nApparel-grade, dermatologist-tested materials and clean diaper ingredients can provide your baby comfort and you some valuable peace of mind. \nAnd you can’t underestimate the convenience of a diaper subscription (especially with some babies needing half a dozen diapers a day). Our diaper subscription means the diapers show up to your door automatically on a schedule that works for you—no more 10 PM runs to the store when you inevitably realize mid-diaper change that you are, in fact, out of diapers.\n\n\nQ2: What causes diaper rash, and how can I help prevent it?\nA2: Diaper rash is very common! About half of all babies develop diaper rash at some point during their first years. Excess moisture can lead to microbial growth and skin irritation—the diaper area is damp, warm, and an ideal environment for bacteria and yeast. Diapers that hold moisture well and absorb quickly can help minimize the likelihood of diaper rash. Based on lab testing, The Diaper absorbs up to 4x faster and keeps skin up to 3x drier than leading brands to reduce the likelihood of irritation.\nFragrances, certain dyes, and chemicals like chlorine may also contribute to skin barrier disruption. \n\n\nQ3: Who decides what ingredients diapers should be ‘free of’? \nA3: Believe it or not, baby diapers aren’t a regulated product category since they’re not intended to be ingested or absorbed by the skin (even though babies are in close contact with their diapers almost 24/7 for their first years of life!). However, as a team of many parents, we go above and beyond industry norms in developing our safety standards with third-party labs (since these labs aren’t affiliated with our brand, there aren’t result biases).\nOur diapers undergo two types of tests: The first is an analytical test where an independent'}]

# Loop through model names
# - start vllm
# - call generate with single model name, get output
# - call generate again and check to make sure it is the same
# - exit vllm

def model_size_to_url(model_size):
    if model_size == "8b":
        return "http://localhost:8003/v1"
    elif model_size == "70b":
        return "http://localhost:8002/v1"
    else:
        raise ValueError(f"Unknown model size: {model_size}")


class VLLMServer:
    def __init__(self, max_loras: int, model_size: str):
        self.max_loras = max_loras
        self._server = None
        self.model_size = model_size

    def get_models(self):
        import requests
        url = model_size_to_url(self.model_size) + "/models"
        r = requests.get(url)
        if r.status_code == 200:
            models = r.json()
            return models
        else:
            raise Exception(f"Failed to get models: {r.status_code} {r.text}")

    def __enter__(self):
        import subprocess
        import requests
        # ./start_vllm_llama8b_1xa100.sh /spiffy-train-dev/base-models/llama-3.1-8b-instruct /tmp/lora-8b/  5  8
        if self.model_size == "8b":
            cmd = [
                "./start_vllm_llama8b_1xa100.sh",
                "/spiffy-train-dev/base-models/llama-3.1-8b-instruct",
                "/tmp/lora-8b/",
                "5,6",
            ]
        elif self.model_size == "70b":
            cmd = [
                "./start_vllm_h100.sh",
                "/spiffy-train-dev/base-models/llama-3.1-70b-instruct",
                "/tmp/lora-70b/",
                "0,1,2,3",
            ]

        cmd.append(str(self.max_loras))
        self._server = subprocess.Popen(cmd)
        while True:
            try:
                _ = self.get_models()
                break
            except:
                time.sleep(1)

    def __exit__(self, exc_type, exc_val, exc_tb):
        import subprocess
        if self._server:
            subprocess.run(["pkill", "-f", "vllm"])
            while True:
                try:
                    _ = self.get_models()
                except:
                    break


def check_multilora():
    """
    Diagnose the broken generations with lora.

    (1) Get the "gold truth" generations. This assumes the happy path of (a) starting VLLM, (b) making a request for a single lora model as the only request leads to correct generations.  In practice they look good, although greedy decoding is not deterministic for some of the models.
    (2) Run VLLM in production setting with many lora models.  Deploy N models with configurable max_loras, and make requests for each model incrementally or in parallel, check results.
    """
    # 70B
    model_size = "70b"

    if model_size == "70b":
        models = [
            "ft-caraway-20241027",
            'ft-jordan-craig-20250313',
            'ft-mantra-brand-20250211',
            'ft-uncle-arnies-20241110',
            'ft-carbahn-20250213',
            'ft-spanx-20250306',
            'ft-little-words-project-20241115',
            'ft-supergoop-20241119',
            'ft-coterie-20241025',
        ]
    elif model_size == "8b":
        models = [
             'ft-little-words-project-20241115',
             'ft-spanx-20241126',
             'ft-coterie-20241025',
             'ft-uncle-arnies-20241110',
             'ft-supergoop-20241119',
        ]

    vllm_client = get_vllm_client(model_size_to_url(model_size), api_key="sk-")

    gold_responses = {}
    for model_name in models:
        with VLLMServer(max_loras=8, model_size=model_size) as vllm_server:
            local_kwargs = {
                'stream': False,
                'guided_regex': 'GOAL: (question answer|pdp_visit)\n(?s).*',
                'max_tokens': 400,
                'temperature': 0,
                # 'top_p': 0.95,
                'model': model_name,
            }
            response = vllm_client.get_chat_response(prompt, **local_kwargs)
            print(model_name)
            print(response)
            gold_responses[model_name] = [response]
            print("-" * 50)

            # check next 3 responses, should be deterministic with greedy decoding!
            for k in range(3):
                response2 = vllm_client.get_chat_response(prompt, **local_kwargs)
                gold_responses[model_name].append(response2)
                print(response2)
            print("=" * 100)

    for model_name, responses in gold_responses.items():
        print(model_name)
        unique_responses = set(responses)
        print(f"Unique responses: {len(unique_responses)}")
        for response in unique_responses:
            print(response)
            print("-" * 30)
        print("=" * 100)

    with open(f"gold_responses_{model_size}.json", "w") as f:
        import json
        json.dump(gold_responses, f, indent=2)

    # Now start the server and call all models.
    test_mode = "incremental"  # round robin through models and call one at a time
    # test_mode = "batch"          # call all models in batch
    all_responses_single_server = {}
    with VLLMServer(max_loras=12, model_size=model_size) as vllm_server:
        if test_mode == 'incremental':
            for k in range(5):
                for model_name in models:
                    local_kwargs = {
                        'stream': False,
                        'guided_regex': 'GOAL: (question answer|pdp_visit)\n(?s).*',
                        'max_tokens': 400,
                        'temperature': 0,
                        # 'top_p': 0.95,
                        'model': model_name,
                    }
                    response = vllm_client.get_chat_response(prompt, **local_kwargs)
                    print(model_name)
                    print(response)
                    if response not in gold_responses[model_name]:
                        print("Response not in gold responses!")
                    print("-" * 50)
                    if model_name not in all_responses_single_server:
                        all_responses_single_server[model_name] = []
                    all_responses_single_server[model_name].append(response)
        elif test_mode == 'batch':
            import uuid
            for k in range(5):
                local_kwargs = {
                            'stream': False,
                            'guided_regex': 'GOAL: (question answer|pdp_visit)\n(?s).*',
                            'max_tokens': 400,
                            'temperature': 0,
                            # 'top_p': 0.95,
                            'model': model_name,
                }
                batch = [
                    {"id": str(uuid.uuid4()), "messages": prompt, "kwargs": dict(local_kwargs)} for _ in range(len(models))
                ]
                for ii, model_name in enumerate(models):
                    batch[ii]["kwargs"]["model"] = model_name
    
                batch_responses = vllm_client.get_batch_chat_responses(batch, num_workers=len(models))
                for response in batch_responses:
                    response_id = response["id"]
                    batch_element = [b for b in batch if b["id"] == response_id][0]
                    model_name = batch_element["kwargs"]["model"]
                    if model_name not in all_responses_single_server:
                        all_responses_single_server[model_name] = []
                    all_responses_single_server[model_name].append(response["response"])


    for model_name, responses in all_responses_single_server.items():
        print(model_name)
        for response in responses:
            print(response)
            print("-" * 30)
        print("=" * 100)



def check_prod_vs_dev():
    """
    Send the same request to dev and prod VLLM servers and check the responses.
    """
    prod_url = "https://inference-llama-3-70b-usw1.spiffy.ai/v1"
    dev_url = "https://inference-llama-3-70b-usc1.dev.spiffy.ai/v1"

    kwargs = {
        "model": "ft-coterie-20241025",
        "api_key": "sk-",
    }

    prod_client = get_vllm_client(prod_url, **kwargs)
    dev_client = get_vllm_client(dev_url, **kwargs)

    local_kwargs = {
        'stream': False,
        'guided_regex': 'GOAL: (question answer|pdp_visit)\n(?s).*',
        'max_tokens': 400,
        'temperature': 0,
        'top_p': 0.95,
    }

    prod_response = prod_client.get_chat_response(prompt, **local_kwargs)
    print(prod_response)

    print("=" * 100)

    dev_response = dev_client.get_chat_response(prompt, **local_kwargs)
    print(dev_response)

